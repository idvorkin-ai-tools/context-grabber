//  The whiteboard's geometry (spec 2026-11-01-whiteboard-design.md, stories 341–343): how big the board is, where the
//  view opens, and what part of it the picture for Larry covers.

import CoreGraphics
import Foundation

public enum WhiteboardFrame {
  /// The board's side in points. ponytail: a fixed square, ten iPad screens each way from the middle, standing in for
  /// an infinite board; grow it (and shift the drawing) when a real drawing reaches an edge.
  public static let side: CGFloat = 20_000
  /// Blank board kept around the drawing in Larry's picture.
  public static let margin: CGFloat = 40
  /// The picture's pixel budget: `maxPixels` squared, spent on whatever shape the drawing is (story 420). A cap on
  /// the long side alone sent a tall column of notes as a 248 x 2048 sliver with the handwriting five pixels high
  /// (Igor, 2026-11-03: "maybe zoom into the pages").
  public static let maxPixels: CGFloat = 2048
  /// The long side, at most: what the model APIs behind the Cockpit still take whole.
  public static let maxLong: CGFloat = 8000
  /// Never drawn finer than the iPad's own screen.
  public static let maxScale: CGFloat = 2

  /// The scroll offset that puts the drawing's centre (the board's middle when nothing is drawn) in the middle of
  /// `viewport`, kept on the board.
  public static func openingOffset(drawing: CGRect?, viewport: CGSize) -> CGPoint {
    let centre =
      drawing.flatMap { $0.isNull || $0.isEmpty ? nil : CGPoint(x: $0.midX, y: $0.midY) }
      ?? CGPoint(x: side / 2, y: side / 2)
    let clamp = { (v: CGFloat, span: CGFloat) in min(max(v - span / 2, 0), max(side - span, 0)) }
    return CGPoint(x: clamp(centre.x, viewport.width), y: clamp(centre.y, viewport.height))
  }

  /// Larry's picture: the drawing plus a margin, kept `within` (the pages a picture on paper shows, story 433), and the
  /// scale that keeps it within the pixel budget and the long side within `maxLong`. Nil for an empty drawing.
  public static func export(_ drawing: CGRect, within: CGRect = .infinite) -> (rect: CGRect, scale: CGFloat)? {
    guard !drawing.isNull, !drawing.isEmpty else { return nil }
    let rect = drawing.insetBy(dx: -margin, dy: -margin).intersection(within)
    guard !rect.isNull, !rect.isEmpty else { return nil }
    let budget = (maxPixels * maxPixels / (rect.width * rect.height)).squareRoot()
    let scale = min(maxScale, budget, maxLong / max(rect.width, rect.height))
    return (rect, scale)
  }

  /// Grid lines in board points, at the finest; doubled as the board shrinks so they stay at least `gridMinGap` apart on
  /// screen, which bounds the lines however far it is pinched out, and the lines that stay were lines already.
  public static let gridStep: CGFloat = 40
  public static let gridMinGap: CGFloat = 24

  /// The lines that cover a viewport, in the canvas's own (zoomed) points.
  public struct Grid: Equatable, Sendable {
    public var origin: CGPoint
    /// Between neighbouring lines.
    public var gap: CGFloat
    public var across: Int
    public var down: Int
  }

  /// #624: what moved between two versions of a drawing with the same strokes, by each stroke's box. `dx`/`dy` are the
  /// first moved stroke's, `topY` the highest moved stroke's top. Nil when nothing moved or the counts differ.
  public static func strokesMoved(before: [CGRect], after: [CGRect]) -> (
    count: Int, dx: CGFloat, dy: CGFloat, topY: CGFloat
  )? {
    guard before.count == after.count else { return nil }
    let moved = zip(before, after).filter { $0 != $1 }
    guard let first = moved.first else { return nil }
    return (
      moved.count, first.1.minX - first.0.minX, first.1.minY - first.0.minY, moved.map(\.0.minY).min() ?? first.0.minY
    )
  }

  /// The board points between lines at `zoom`: how the grid and the ruled lines thin.
  public static func lineStep(zoom: CGFloat) -> CGFloat {
    var step = gridStep
    while step * zoom < gridMinGap { step *= 2 }
    return step
  }

  /// `offset` and `viewport` in zoomed points. Equal until the view crosses a line, so nothing moves between crossings.
  public static func grid(offset: CGPoint, viewport: CGSize, zoom: CGFloat) -> Grid {
    let gap = lineStep(zoom: zoom) * zoom
    return Grid(
      origin: CGPoint(x: (offset.x / gap).rounded(.down) * gap, y: (offset.y / gap).rounded(.down) * gap), gap: gap,
      across: Int((viewport.width / gap).rounded(.up)) + 2, down: Int((viewport.height / gap).rounded(.up)) + 2)
  }
}
