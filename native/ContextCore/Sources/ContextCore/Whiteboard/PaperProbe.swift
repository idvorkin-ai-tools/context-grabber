//  The arithmetic of the trial on paper (whiteboard spec's "Trial on paper", stories 437, 439; #635, #636). Temporary,
//  like the trial: the real page geometry gets its own home when the board moves to PaperKit. PaperKit stays in the
//  app: here, the column a copy of a board sits in, which ink a change moved, and what came of a touch.

import CoreGraphics
import Foundation

public enum PaperProbe {
  public static let pageWidth: CGFloat = 820
  public static let pageHeight: CGFloat = 1060
  /// Blank paper kept between the column's corner and the ink.
  public static let margin: CGFloat = 40
  /// The tall layout's markup: past page 11, and more than a trial's ink should reach.
  public static let tallPages = 40
  /// Where an empty board's column starts when the ink stays where it is: the middle of the old board.
  public static let oldMiddle = CGPoint(x: 10_000, y: 10_000)

  /// The ways of placing a copy of a board that the questions need.
  public enum Layout: String, CaseIterable, Sendable {
    /// The column starts at the ink: a non-zero origin, nothing moved (question 4).
    case inkInPlace = "ink_in_place"
    /// The ink moved to the top of a column at the origin.
    case moved
    /// A column at the origin held much taller than it shows, cut short by the view: growing touches no markup (question 2's fallback).
    case tall
  }

  public struct Column: Equatable, Sendable {
    public var origin: CGPoint
    public var width: CGFloat
    /// Pages a person can reach.
    public var pages: Int
    /// Pages the markup holds; more than `pages` only when tall.
    public var heldPages: Int
    /// What to move the ink by.
    public var shift: CGVector

    public var bounds: CGRect {
      CGRect(x: origin.x, y: origin.y, width: width, height: CGFloat(heldPages) * pageHeight)
    }

    /// How much of the held column is cut off the bottom, in board points.
    public var trim: CGFloat { CGFloat(heldPages - pages) * pageHeight }

    /// The page holding `y` on the board, 1-based, within the pages a person can reach.
    public func page(at y: CGFloat) -> Int {
      min(max(Int(((y - origin.y) / pageHeight).rounded(.down)) + 1, 1), pages)
    }

    /// True when ink as low as `inkMaxY` leaves no blank page below it.
    public func needsPage(inkMaxY: CGFloat) -> Bool {
      inkMaxY > origin.y + CGFloat(pages - 1) * pageHeight
    }

    /// The small cross on a page, in points from the column's corner: what the ring is placed on.
    public func cross(page: Int) -> CGPoint {
      CGPoint(x: width / 2, y: CGFloat(page - 1) * pageHeight + 200)
    }
  }

  /// A page wide (wider for ink that's wider), with the ink's pages and a blank one below.
  public static func column(ink: CGRect?, layout: Layout) -> Column {
    let drawn = ink.flatMap { $0.isNull || $0.isEmpty ? nil : $0 }
    let width = max(pageWidth, (drawn?.width ?? 0) + margin * 2)
    let pages = Int((((drawn?.height ?? 0) + margin * 2) / pageHeight).rounded(.up)) + 1
    switch layout {
    case .inkInPlace:
      let origin = drawn.map { CGPoint(x: $0.minX - margin, y: $0.minY - margin) } ?? oldMiddle
      return Column(origin: origin, width: width, pages: pages, heldPages: pages, shift: .zero)
    case .moved, .tall:
      let shift = drawn.map { CGVector(dx: margin - $0.minX, dy: margin - $0.minY) } ?? .zero
      return Column(
        origin: .zero, width: width, pages: pages, heldPages: layout == .tall ? max(tallPages, pages) : pages,
        shift: shift)
    }
  }

  /// The zoom that fits a width on screen, from what one zoom scale showed: what zoom 1.0 means is the trial's to find
  /// out, so nothing here assumes it. Nil until a width has been seen.
  public static func fitZoom(visibleWidth: CGFloat, atZoom zoom: CGFloat, column: CGFloat) -> CGFloat? {
    guard visibleWidth > 0, zoom > 0, column > 0 else { return nil }
    return visibleWidth * zoom / column
  }

  public struct InkMove: Equatable, Sendable {
    public var id: String
    public var dx: CGFloat
    public var dy: CGFloat
    /// It changed size too.
    public var resized: Bool

    public init(id: String, dx: CGFloat, dy: CGFloat, resized: Bool) {
      self.id = id
      self.dx = dx
      self.dy = dy
      self.resized = resized
    }
  }

  public struct InkChange: Equatable, Sendable {
    public var added: [String] = []
    public var removed: [String] = []
    public var moved: [InkMove] = []
    public var isEmpty: Bool { added.isEmpty && removed.isEmpty && moved.isEmpty }
  }

  /// What a change did to the ink, by each element's id and frame. Sorted by id, so the same change logs the same.
  public static func inkChange(before: [String: CGRect], after: [String: CGRect]) -> InkChange {
    var change = InkChange()
    change.added = after.keys.filter { before[$0] == nil }.sorted()
    change.removed = before.keys.filter { after[$0] == nil }.sorted()
    change.moved = after.keys.sorted().compactMap { id in
      guard let old = before[id], let new = after[id], !close(old, new) else { return nil }
      return InkMove(
        id: id, dx: new.minX - old.minX, dy: new.minY - old.minY,
        resized: abs(new.width - old.width) > tolerance || abs(new.height - old.height) > tolerance)
    }
    return change
  }

  private static let tolerance: CGFloat = 0.01

  private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance && abs(a.width - b.width) <= tolerance
      && abs(a.height - b.height) <= tolerance
  }

  /// What one touch, from its first finger down to its last up, is seen to have done.
  public struct TouchFacts: Equatable, Sendable {
    public var seconds: Double = 0
    /// The furthest a touch went from where it started, in screen points.
    public var travel: CGFloat = 0
    public var fingers: Int = 1
    /// The view moved, in board points.
    public var scrolled: CGFloat = 0
    public var zoomChanged: Bool = false
    public var selectionChanges: Int = 0
    public var inkAdded: Int = 0
    public var inkRemoved: Int = 0
    public var inkMoved: Int = 0
    public var beganDrawing: Bool = false

    public init() {}
  }

  /// A tap is short and stays put; the rest is whatever was seen, in a fixed order, or `nothing`.
  public static func outcome(_ facts: TouchFacts) -> [String] {
    var seen: [String] = []
    if facts.scrolled > 0.5 { seen.append("panned") }
    if facts.zoomChanged { seen.append("zoomed") }
    if facts.selectionChanges > 0 { seen.append("selected") }
    if facts.inkMoved > 0 { seen.append("moved_ink") }
    if facts.inkAdded > 0 || facts.beganDrawing { seen.append("drew") }
    if facts.inkRemoved > 0 { seen.append("erased") }
    return seen.isEmpty ? ["nothing"] : seen
  }

  public static func gesture(_ facts: TouchFacts) -> String {
    if facts.fingers > 1 { return "multi" }
    return facts.travel < 10 && facts.seconds < 0.5 ? "tap" : (facts.travel < 10 ? "press" : "drag")
  }

  /// One scroll or pinch, from the first change seen to the view settling: how often the delegate reported it against
  /// what each screen frame could see, and how far a thing placed from the delegate's numbers slipped (question 3).
  public struct Glide: Equatable, Sendable {
    public private(set) var delegateCalls = 0
    public private(set) var maxGap: Double = 0
    /// Screen frames seen, those where the visible area had moved, and those where it had moved past what the delegate last said.
    public private(set) var ticks = 0
    public private(set) var movedTicks = 0
    public private(set) var staleTicks = 0
    public private(set) var maxSlip: CGFloat = 0
    private var lastCall: Double?

    public init() {}

    public mutating func delegateCalled(at time: Double) {
      if let lastCall { maxGap = max(maxGap, time - lastCall) }
      lastCall = time
      delegateCalls += 1
    }

    public mutating func tick(moved: Bool, stale: Bool, slip: CGFloat) {
      ticks += 1
      if moved { movedTicks += 1 }
      if stale { staleTicks += 1 }
      maxSlip = max(maxSlip, slip)
    }
  }

  /// `a` as it came back as `b`: same ink in the same order, or what differs.
  public struct RoundTrip: Equatable, Sendable {
    public var count: Int
    public var countBack: Int
    public var sameOrder: Bool
    public var missing: Int
    public var extra: Int
    /// The first few ids that went missing, to look up in the board's strokes.
    public var firstMissing: [String]
  }

  public static func roundTrip(_ a: [String], _ b: [String]) -> RoundTrip {
    let there = Set(b)
    let here = Set(a)
    let gone = a.filter { !there.contains($0) }
    return RoundTrip(
      count: a.count, countBack: b.count, sameOrder: a == b, missing: gone.count,
      extra: b.filter { !here.contains($0) }.count, firstMissing: Array(gone.prefix(3)))
  }
}
