//  Shapes that snap (spec 2026-11-16-whiteboard-to-text-and-snap-design.md, stories 923–925): a stroke held still at its
//  end that is nearly a line, a rectangle or an ellipse, cleaned up. Ported from the web board's `cleanShape`
//  (cockpit assets/ink/board.mjs) with its thresholds, so the two boards snap the same strokes. Board points throughout.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardShapeSnap {
  /// How far off a shape a stroke may be, as a share of its size (the web board's `SNAP_*_ERR`).
  public static let lineError: CGFloat = 0.06
  public static let rectError: CGFloat = 0.07
  public static let ellipseError: CGFloat = 0.1
  /// A stroke smaller than this never snaps.
  public static let smallest: CGFloat = 30
  /// The Pencil held this long, moving less than `stillWithin`, at a stroke's end asks for the snap.
  public static let hold: Double = 0.5
  public static let stillWithin: CGFloat = 5

  public struct Shape: Equatable, Sendable {
    public enum Kind: String, Sendable { case line, rect, ellipse }
    public var kind: Kind
    /// The clean stroke's points, about every 4 board points along it.
    public var points: [CGPoint]
    /// How far off the shape the stroke was, as a share of its size, to three places.
    public var error: Double
  }

  /// The clean shape `points` nearly is, or nil.
  public static func clean(_ points: [CGPoint]) -> Shape? {
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    guard points.count >= 4, let a = points.first, let z = points.last, let left = xs.min(), let right = xs.max(),
      let top = ys.min(), let bottom = ys.max()
    else { return nil }
    let (w, h) = (right - left, bottom - top)
    let size = max(w, h)
    guard size >= smallest else { return nil }
    let chord = hypot(z.x - a.x, z.y - a.y)
    // A line: every point near the chord.
    if chord >= smallest {
      let dev = points.map { distance($0, toSegment: a, z) }.max() ?? 0
      if dev / chord <= lineError {
        return Shape(kind: .line, points: densify([a, z]), error: thousandths(dev / chord))
      }
    }
    // Closed: the ends meet within a fifth of its size, and it has some body.
    guard chord <= size * 0.2, min(w, h) >= smallest / 2 else { return nil }
    let mean = { (f: (CGPoint) -> CGFloat) in points.reduce(0) { $0 + f($1) } / CGFloat(points.count) }
    let rectErr = mean { min($0.x - left, right - $0.x, $0.y - top, bottom - $0.y) } / ((w + h) / 2)
    let (cx, cy, rx, ry) = ((left + right) / 2, (top + bottom) / 2, w / 2, h / 2)
    let ellErr = mean { abs(hypot(($0.x - cx) / rx, ($0.y - cy) / ry) - 1) }
    // The rectangle's corners must be visited, or a rounded loop reads as one.
    let corners = [
      CGPoint(x: left, y: top), CGPoint(x: right, y: top), CGPoint(x: right, y: bottom), CGPoint(x: left, y: bottom),
    ]
    let cornered = corners.allSatisfy { c in points.contains { hypot($0.x - c.x, $0.y - c.y) < size * 0.15 } }
    if cornered, rectErr <= rectError {
      return Shape(kind: .rect, points: densify(corners + [corners[0]]), error: thousandths(rectErr))
    }
    guard ellErr <= ellipseError else { return nil }
    let n = max(24, Int((CGFloat.pi * (rx + ry) / 4).rounded()))
    let t0 = atan2((a.y - cy) / ry, (a.x - cx) / rx)
    let ring = (0...n).map { k -> CGPoint in
      let t = t0 + 2 * .pi * CGFloat(k) / CGFloat(n)
      return CGPoint(x: tenth(cx + rx * cos(t)), y: tenth(cy + ry * sin(t)))
    }
    return Shape(kind: .ellipse, points: ring, error: thousandths(ellErr))
  }

  /// Whether a stroke ended held still, from where the Pencil was as it went: it last moved `stillWithin` or more at
  /// least `hold` seconds before it lifted. The web board's timer, read at the lift.
  public struct Hold: Equatable, Sendable {
    private var anchor: CGPoint?
    private var since: Double = 0

    public init() {}

    /// The Pencil at `point` (board points) at `time` (seconds, any clock the lift uses too).
    public mutating func moved(to point: CGPoint, at time: Double) {
      if let anchor, hypot(point.x - anchor.x, point.y - anchor.y) < stillWithin { return }
      anchor = point
      since = time
    }

    /// The Pencil lifted at `point` at `time`.
    public mutating func held(liftedAt point: CGPoint, time: Double) -> Bool {
      moved(to: point, at: time)
      return time - since >= hold
    }
  }

  /// What Undo says for a snap, and the note's word for it.
  public static func name(_ kind: Shape.Kind) -> String {
    switch kind {
    case .line: "line"
    case .rect: "rectangle"
    case .ellipse: "ellipse"
    }
  }

  static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
    let (dx, dy) = (b.x - a.x, b.y - a.y)
    let span = dx * dx + dy * dy
    let t = span > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / span)) : 0
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
  }

  /// The corners joined by points about every `step` board points.
  static func densify(_ corners: [CGPoint], step: CGFloat = 4) -> [CGPoint] {
    var out: [CGPoint] = []
    for (a, b) in zip(corners, corners.dropFirst()) {
      let n = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
      for k in 0..<n {
        let t = CGFloat(k) / CGFloat(n)
        out.append(CGPoint(x: tenth(a.x + (b.x - a.x) * t), y: tenth(a.y + (b.y - a.y) * t)))
      }
    }
    if let last = corners.last { out.append(CGPoint(x: tenth(last.x), y: tenth(last.y))) }
    return out
  }

  private static func tenth(_ v: CGFloat) -> CGFloat { (v * 10).rounded() / 10 }
  private static func thousandths(_ v: CGFloat) -> Double { Double((v * 1000).rounded() / 1000) }
}
