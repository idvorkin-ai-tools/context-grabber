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
  /// The picture's longer side, at most.
  public static let maxPixels: CGFloat = 2048
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

  /// Larry's picture: the drawing plus a margin, and the scale that keeps its longer side within `maxPixels`. Nil for
  /// an empty drawing.
  public static func export(_ drawing: CGRect) -> (rect: CGRect, scale: CGFloat)? {
    guard !drawing.isNull, !drawing.isEmpty else { return nil }
    let rect = drawing.insetBy(dx: -margin, dy: -margin)
    let scale = min(maxScale, maxPixels / max(rect.width, rect.height))
    return (rect, scale)
  }
}
