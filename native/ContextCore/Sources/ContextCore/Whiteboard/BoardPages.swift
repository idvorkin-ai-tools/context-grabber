//  The column of pages a board on paper is (spec 2026-11-01-whiteboard-design.md, "The board is a column of pages",
//  stories 535–539; #636). All in board points, with page 1's corner at the board's origin: zoom only thins the ruled
//  lines. PaperKit stays in the app.

import CoreGraphics
import Foundation

public struct BoardPages: Equatable, Sendable {
  public static let pageWidth: CGFloat = 820
  public static let pageHeight: CGFloat = 1060
  /// Blank paper kept between the column's corner and ink moved onto it.
  public static let margin: CGFloat = 40

  /// Wider than a page only for wider ink; pages never get taller for it.
  public var width: CGFloat

  public init(width: CGFloat = pageWidth) {
    self.width = width
  }

  /// The page holding `point`, 1-based. A point on a page's end is on the next page; one above the column is on page 1.
  /// `x` plays no part: past the side is still that page, and widens the board. The page mostly on a screen is the one
  /// at the screen's middle.
  public func page(at point: CGPoint) -> Int {
    pagesDown(to: point.y, .down) + 1
  }

  /// The page's whole rectangle: its top and bottom are the page's edges.
  public func frame(ofPage page: Int) -> CGRect {
    CGRect(x: 0, y: CGFloat(page - 1) * Self.pageHeight, width: width, height: Self.pageHeight)
  }

  public func bounds(pages: Int) -> CGRect {
    CGRect(x: 0, y: 0, width: width, height: CGFloat(pages) * Self.pageHeight)
  }

  /// Where each page's faint end line goes.
  public func pageEnds(pages: Int) -> [CGFloat] {
    pages > 0 ? (1...pages).map { frame(ofPage: $0).maxY } : []
  }

  /// The pages ink as low as `inkMaxY` needs: the ones down to it and one blank below. No ink is the one blank page.
  /// Ink that stops at a page's end leaves the page below blank, though a single point on that line is on it
  /// (`page(at:)`): this is how far ink reaches, that is where one place is.
  public func pagesNeeded(inkMaxY: CGFloat?) -> Int {
    guard let inkMaxY, inkMaxY.isFinite else { return 1 }
    return max(pagesDown(to: inkMaxY, .up), 1) + 1
  }

  /// The pages a board on paper should hold after a change: never fewer while it's open, as erasing leaves room. While
  /// redo has steps waiting nothing is added, so he can step back and forward through what he did; his next new stroke
  /// clears them, and adds whatever page is due.
  public func pages(after current: Int, inkMaxY: CGFloat?, redoWaiting: Bool) -> Int {
    redoWaiting ? current : max(current, pagesNeeded(inkMaxY: inkMaxY))
  }

  /// Where a paste may land: the column's width, and as far down as he likes, as a paste brings its pages.
  public var pasteReach: CGRect {
    CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude)
  }

  /// How far to move copied ink so its middle is in the middle of `visible`, inside the column's width where it fits and above
  /// nothing: a wider one starts at the column's left.
  public func pasteShift(ink: CGRect, visible: CGRect) -> CGVector {
    let x = min(max(visible.midX - ink.width / 2, 0), max(width - ink.width, 0))
    let y = max(visible.midY - ink.height / 2, 0)
    return CGVector(dx: x - ink.minX, dy: y - ink.minY)
  }

  /// How many pages a column of this height holds, at least one.
  public func pages(in bounds: CGRect) -> Int {
    let held = (bounds.height / Self.pageHeight).rounded()
    return held.isFinite ? max(Int(min(held, Self.mostPages)), 1) : 1
  }

  /// A mark reaching past the column's sides or above its top, which paper can't show until a mark past the edge widens the
  /// board. ponytail: only told, not handled; that step is what removes this.
  public func reachesPastSide(_ lines: [[CGPoint]]) -> Bool {
    lines.joined().contains { $0.x < 0 || $0.x > width || $0.y < 0 }
  }

  /// The corner's *Page 2 of 3*, for the page at the middle of the view: the one mostly on screen. Below the column it's
  /// still the last page.
  public func pageText(visibleMidY: CGFloat, pages: Int) -> String {
    "Page \(min(page(at: CGPoint(x: 0, y: visibleMidY)), max(pages, 1))) of \(max(pages, 1))"
  }

  /// Where a board opens: where he left it on this device, or the first page if he never has. A place past the end,
  /// from ink erased since, is the last page's top.
  public func openingY(remembered: Double?, pages: Int) -> CGFloat {
    guard let remembered, remembered.isFinite else { return 0 }
    return min(max(CGFloat(remembered), 0), frame(ofPage: max(pages, 1)).minY)
  }

  /// The zoom that fits a width on screen, from what one zoom scale showed. Nil until a width has been seen.
  public static func fitZoom(visibleWidth: CGFloat, atZoom zoom: CGFloat, column: CGFloat) -> CGFloat? {
    guard visibleWidth > 0, zoom > 0, column > 0 else { return nil }
    return visibleWidth * zoom / column
  }

  /// The grid within `visible` (board points), on the first `pages` pages: squares from the column's corner that run on
  /// unbroken from page to page, thinned by zoom as the ruled lines are. None on the column's own edges.
  public func gridLines(visible: CGRect, pages: Int, zoom: CGFloat) -> (across: [CGFloat], down: [CGFloat]) {
    guard zoom > 0, pages > 0 else { return ([], []) }
    let step = WhiteboardFrame.lineStep(zoom: zoom)
    let column = bounds(pages: pages)
    func lines(_ low: CGFloat, _ high: CGFloat, end: CGFloat) -> [CGFloat] {
      let first = max((low / step).rounded(.up), 1)
      let last = min((high / step).rounded(.down), ((end - 0.5) / step).rounded(.down))
      guard first.isFinite, last.isFinite, first <= last else { return [] }
      return stride(from: first, through: last, by: 1).map { $0 * step }
    }
    return (lines(visible.minX, visible.maxX, end: column.maxX), lines(visible.minY, visible.maxY, end: column.maxY))
  }

  /// The ruled lines within `visible` (board `y`), on the first `pages` pages. Every page is ruled the same from its
  /// own top, so a line never lands on a page's end; thinned by zoom as the grid is, so the lines that stay were lines
  /// already.
  public func ruledLines(visible: ClosedRange<CGFloat>, pages: Int, zoom: CGFloat) -> [CGFloat] {
    guard zoom > 0, pages > 0 else { return [] }
    let step = WhiteboardFrame.lineStep(zoom: zoom)
    let first = page(at: CGPoint(x: 0, y: visible.lowerBound))
    let last = min(page(at: CGPoint(x: 0, y: visible.upperBound)), pages)
    guard first <= last else { return [] }
    return (first...last).flatMap { page -> [CGFloat] in
      let top = frame(ofPage: page).minY
      return stride(from: top + step, to: top + Self.pageHeight, by: step).filter { visible.contains($0) }
    }
  }

  /// Ink moving onto pages: only ever a translation, so no stroke can scale, and the strokes keep their places relative
  /// to each other.
  public struct Placement: Equatable, Sendable {
    public var shift: CGVector
    public var board: BoardPages
    public var pages: Int

    public var transform: CGAffineTransform { CGAffineTransform(translationX: shift.dx, y: shift.dy) }
  }

  /// `ink` at the first page's corner, inside a margin, on a board as wide as it needs. No ink needs no move.
  public static func placing(ink: CGRect?) -> Placement {
    guard let ink = drawn(ink) else { return Placement(shift: .zero, board: BoardPages(), pages: 1) }
    let board = BoardPages(width: width(forInkWidth: ink.width))
    return Placement(
      shift: CGVector(dx: margin - ink.minX, dy: margin - ink.minY), board: board,
      pages: board.pagesNeeded(inkMaxY: margin + ink.height))
  }

  /// A page wide, or wider for wider ink, with a margin each side.
  static func width(forInkWidth inkWidth: CGFloat) -> CGFloat {
    max(pageWidth, inkWidth + margin * 2)
  }

  /// The ink's box, if it's a box of anything.
  static func drawn(_ ink: CGRect?) -> CGRect? {
    ink.flatMap { $0.isNull || $0.isEmpty || $0.isInfinite ? nil : $0 }
  }

  /// Whole pages from the column's top to `y`, 0 at or above the top. A page number that can't be real can't crash.
  private func pagesDown(to y: CGFloat, _ rule: FloatingPointRoundingRule) -> Int {
    let pages = (y / Self.pageHeight).rounded(rule)
    return pages.isFinite ? Int(min(max(pages, 0), Self.mostPages)) : 0
  }

  private static let mostPages: CGFloat = 1_000_000
}
