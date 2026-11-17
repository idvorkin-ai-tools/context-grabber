//  Scratch out (spec 2026-11-01-whiteboard-design.md, *Scratch out*; stories 890, 891): a fast zigzag over ink deletes
//  the strokes it covers, as in Goodnotes and Notability. Ported from the Cockpit's web board (`scratchShape`,
//  `scratchOut` and `eraseHits` in assets/ink/board.mjs) with its thresholds, so both boards feel the same. Board points
//  throughout; the app hands in the zigzag and the board's strokes, and removes what this names.

import Foundation

public enum WhiteboardScratchOut {
  /// Turns back along the zigzag's main direction, at least.
  public static let reversals = 3
  /// Board points per millisecond, at least.
  public static let speed: Double = 0.5
  /// How near the zigzag a stroke's own line passes to be taken, beyond half its pen.
  static let reach: CGFloat = 4
  /// The part of the touched ink's points that lies inside the zigzag's box (grown by 6).
  static let over: Double = 0.6

  /// A stroke on the board, as the scratch-out sees it.
  public struct Ink: Equatable, Sendable {
    public var id: String
    public var points: [CGPoint]
    public var width: CGFloat

    public init(id: String, points: [CGPoint], width: CGFloat = 3) {
      self.id = id
      self.points = points
      self.width = width
    }
  }

  public struct Shape: Equatable, Sendable {
    public var ok: Bool
    public var reversals: Int
    /// Why it isn't one: short, small, few turns, short sweeps, marches along.
    public var why: String?
  }

  /// The shape alone: three or more turns back along the main axis, each sweep crossing most of it, and no wider across
  /// than it is long, so *mmm* and *www*, whose humps march along, never qualify.
  public static func shape(_ points: [CGPoint]) -> Shape {
    guard points.count >= 8 else { return Shape(ok: false, reversals: 0, why: "short") }
    var (tx, ty) = (CGFloat(0), CGFloat(0))
    for (a, b) in zip(points, points.dropFirst()) {
      tx += abs(b.x - a.x)
      ty += abs(b.y - a.y)
    }
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    let w = (xs.max() ?? 0) - (xs.min() ?? 0)
    let h = (ys.max() ?? 0) - (ys.min() ?? 0)
    let alongY = ty > tx
    let along: (CGPoint) -> CGFloat = { alongY ? $0.y : $0.x }
    let (ext, cross, travel) = alongY ? (h, w, ty) : (w, h, tx)
    guard ext >= 30 else { return Shape(ok: false, reversals: 0, why: "small") }
    // Turns back along the main axis, with hysteresis so jitter is no turn.
    let threshold = 0.35 * ext
    var dir = 0
    var hi = along(points[0])
    var lo = hi
    var turns = 0
    for p in points {
      let v = along(p)
      if dir == 0 {
        hi = max(hi, v)
        lo = min(lo, v)
        if hi - v > threshold {
          dir = -1
          lo = v
        } else if v - lo > threshold {
          dir = 1
          hi = v
        }
      } else if dir > 0 {
        if v > hi {
          hi = v
        } else if hi - v > threshold {
          turns += 1
          dir = -1
          lo = v
        }
      } else if v < lo {
        lo = v
      } else if v - lo > threshold {
        turns += 1
        dir = 1
        hi = v
      }
    }
    if turns < reversals { return Shape(ok: false, reversals: turns, why: "few turns") }
    if travel < 0.8 * CGFloat(turns + 1) * ext { return Shape(ok: false, reversals: turns, why: "short sweeps") }
    if cross > 0.8 * ext { return Shape(ok: false, reversals: turns, why: "marches along") }
    return Shape(ok: true, reversals: turns, why: nil)
  }

  public struct Outcome: Equatable, Sendable {
    public var ok: Bool
    /// The strokes that go with the zigzag, in the board's order. Empty when it isn't a scratch-out.
    public var gone: [String]
    public var reversals: Int
    /// Board points per millisecond, to two places; nil when the time wasn't known.
    public var speed: Double?
    /// Why it stays ink: the shape's reason, or slow, no ink, beside ink.
    public var why: String?
  }

  /// A zigzag fast enough to be a scratch-out, whatever is under it: over a fold's marker there is no ink, and the fold
  /// goes all the same (story 903).
  public static func isZigzag(_ points: [CGPoint], ms: Double?) -> Bool {
    guard shape(points).ok else { return false }
    guard let speed = Self.speed(of: points, ms: ms) else { return true }
    return speed >= Self.speed
  }

  /// Board points per millisecond along `points`, to two places; nil when the time wasn't known.
  static func speed(of points: [CGPoint], ms: Double?) -> Double? {
    guard let ms, ms > 0 else { return nil }
    var travel = 0.0
    for (a, b) in zip(points, points.dropFirst()) { travel += Double(hypot(b.x - a.x, b.y - a.y)) }
    return (travel / ms * 100).rounded() / 100
  }

  /// The zigzag `points`, drawn in `ms` (nil: not known, so not held to the speed), over `ink`: what goes, or why it
  /// stays ink. The zigzag itself is not among `ink`.
  public static func check(_ points: [CGPoint], ms: Double?, over ink: [Ink]) -> Outcome {
    let shape = shape(points)
    let speed = Self.speed(of: points, ms: ms)
    func no(_ why: String?) -> Outcome {
      Outcome(ok: false, gone: [], reversals: shape.reversals, speed: speed, why: why)
    }
    guard shape.ok else { return no(shape.why) }
    if let speed, speed < Self.speed { return no("slow") }
    let hits = touched(by: points, in: ink)
    guard !hits.isEmpty else { return no("no ink") }
    // The ink it touched lies mostly under it, not beside it.
    let zone = box(points).insetBy(dx: -6, dy: -6)
    let taken = Set(hits)
    var (inside, all) = (0, 0)
    for stroke in ink where taken.contains(stroke.id) {
      for p in stroke.points {
        all += 1
        if within(p, zone) { inside += 1 }
      }
    }
    if all > 0, Double(inside) / Double(all) < over { return no("beside ink") }
    return Outcome(ok: true, gone: hits, reversals: shape.reversals, speed: speed, why: nil)
  }

  /// The strokes a line along `path` touches within `reach` of their own line (half the pen added): whole strokes, as
  /// the stroke eraser takes them.
  static func touched(by path: [CGPoint], in ink: [Ink]) -> [String] {
    guard let first = path.first else { return [] }
    let line = path.count > 1 ? path : [first, first]
    let pathBox = box(line)
    return ink.filter { stroke in
      guard let start = stroke.points.first else { return false }
      let pad = reach + stroke.width / 2
      let own = box(stroke.points)
      guard
        pathBox.maxX >= own.minX - pad, pathBox.minX <= own.maxX + pad, pathBox.maxY >= own.minY - pad,
        pathBox.minY <= own.maxY + pad
      else { return false }
      let points = stroke.points.count > 1 ? stroke.points : [start, start]
      for (a, b) in zip(points, points.dropFirst()) {
        for (c, d) in zip(line, line.dropFirst()) where distance(a, b, c, d) <= pad { return true }
      }
      return false
    }.map(\.id)
  }

  /// Inside `box`, its edges included.
  static func within(_ p: CGPoint, _ box: CGRect) -> Bool {
    p.x >= box.minX && p.x <= box.maxX && p.y >= box.minY && p.y <= box.maxY
  }

  static func box(_ points: [CGPoint]) -> CGRect {
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    let (minX, minY) = (xs.min() ?? 0, ys.min() ?? 0)
    return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
  }

  /// Between two segments: 0 when they cross, as end-to-segment distances miss an X.
  static func distance(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGFloat {
    func cross(_ o: CGPoint, _ p: CGPoint, _ q: CGPoint) -> CGFloat {
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x)
    }
    let (d1, d2, d3, d4) = (cross(c, d, a), cross(c, d, b), cross(a, b, c), cross(a, b, d))
    if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) { return 0 }
    return min(toSegment(a, c, d), toSegment(b, c, d), toSegment(c, a, b), toSegment(d, a, b))
  }

  static func toSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let (dx, dy) = (b.x - a.x, b.y - a.y)
    let length = dx * dx + dy * dy
    let t = length > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)) : 0
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
  }
}
