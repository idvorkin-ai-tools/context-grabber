//  Scratch out (spec 2026-11-01-whiteboard-design.md, *Scratch out*; stories 890, 891): a fast zigzag over ink deletes
//  the strokes it covers, as in Goodnotes and Notability. Ported from the Cockpit's web board (`scratchShape`,
//  `scratchOut` and `eraseHits` in assets/ink/board.mjs) with its thresholds, so both boards feel the same. Board points
//  throughout; the app hands in the zigzag and the board's strokes, and removes what this names.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum WhiteboardScratchOut {
  /// Turns back along the zigzag's main direction, at least.
  public static let reversals = 3
  /// Turns back a scribble needs when it wanders along the word, its sweeps crossing only part of its length
  /// (context-grabber-4kj).
  public static let wanderingReversals = 5
  /// A drifting scribble's typical sweep, in board points, at least: a letter's back-and-forth is narrower
  /// (context-grabber-4kj, 2026-11-22).
  static let driftSweep: CGFloat = 40
  /// Jitter, in board points, that is no turn when a drifting scribble's sweeps are first measured.
  static let jitter: CGFloat = 10
  /// Board points per millisecond, at least, for a zigzag `fullSpeedLength` long or longer.
  public static let speed: Double = 0.5
  /// The zigzag's length, in board points, from which it is held to the whole `speed`; a shorter one can't reach a
  /// long one's speed, so its floor scales down with it (cockpit-9g1: a 37-point zigzag went at 0.35).
  static let fullSpeedLength: CGFloat = 60
  /// How near the zigzag a stroke's own line passes to be taken, beyond half its pen.
  static let reach: CGFloat = 4
  /// The part of the touched ink's points that lies inside the zigzag's box (grown by 6).
  static let over: Double = 0.6

  /// A stroke on the board, as the scratch-out sees it.
  public struct Ink: Equatable, Sendable {
    public var id: String
    /// The stretches of the stroke still on the board, never empty: one for a whole stroke, one per part the pixel
    /// eraser left (context-grabber-p5hy). A gap between two is bare paper, so no line runs across it.
    public var runs: [[CGPoint]]
    public var width: CGFloat

    /// Every point still on the board.
    public var points: [CGPoint] { runs.flatMap { $0 } }

    public init(id: String, points: [CGPoint], width: CGFloat = 3) {
      self.init(id: id, runs: [points], width: width)
    }

    public init(id: String, runs: [[CGPoint]], width: CGFloat = 3) {
      self.id = id
      self.runs = runs.filter { !$0.isEmpty }
      self.width = width
    }
  }

  /// The stretches of a stroke's control `points` still on the board, given its `visible` ranges of parametric value
  /// (control point i at i): the points inside each range, with the range's ends where they fall between two, read
  /// `at` (context-grabber-p5hy). A range over the whole stroke gives its points as they are; no ranges, nothing.
  public static func runs(
    _ points: [CGPoint], visible: [ClosedRange<CGFloat>], at point: (CGFloat) -> CGPoint
  ) -> [[CGPoint]] {
    guard !points.isEmpty else { return [] }
    let last = CGFloat(points.count - 1)
    return visible.compactMap { range -> [CGPoint]? in
      let (lo, hi) = (max(0, range.lowerBound), min(last, range.upperBound))
      guard lo <= hi else { return nil }
      var run: [CGPoint] = []
      if lo != lo.rounded(.up) { run.append(point(lo)) }
      let (first, end) = (Int(lo.rounded(.up)), Int(hi.rounded(.down)))
      if first <= end { run += points[first...end] }
      if hi != hi.rounded(.down), hi > lo { run.append(point(hi)) }
      return run.isEmpty ? nil : run
    }
  }

  public struct Shape: Equatable, Sendable {
    public var ok: Bool
    public var reversals: Int
    /// Why it isn't one: short, small, few turns, short sweeps, marches along.
    public var why: String?
    /// A scribble that wanders along the word as it goes (context-grabber-4kj): it scratches out only ink it lies
    /// over; over none, or beside it, it stays ink, as hatching looks the same.
    public var wanders = false
  }

  /// The shape alone: three or more turns back along the main axis, each sweep crossing most of it, and no wider across
  /// than it is long, so *mmm* and *www*, whose humps march along, never qualify. A scribble with five or more turns
  /// whose sweeps cross half its length on average also qualifies, as it `wanders`: a hand scratching out a word drifts
  /// along it, so no sweep spans the whole scribble (context-grabber-4kj: Igor's on 2026-11-21 averaged 63% to 75%).
  /// One that drifts further than its sweeps are long wanders too: its turns counted against its own sweeps, five or
  /// more, its typical sweep `driftSweep` or longer, the pen going at least twice as far along as across, which loops
  /// don't (4kj, 2026-11-22: 458 along, sweeps of 87 to 245, counted 4 turns).
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
    // Counted against its own sweeps rather than its whole length, for a scribble that drifts a long way.
    func drifting(_ why: String) -> Shape {
      let (own, sweep) = drift(points.map(along))
      // Loops (*ooo*, *eee*) turn back too, but the pen goes as far across as along; a scribble's goes mostly along.
      let across = alongY ? tx : ty
      guard own >= wanderingReversals, sweep >= driftSweep, cross <= 0.8 * ext, across <= 0.5 * travel else {
        return Shape(ok: false, reversals: turns, why: why)
      }
      return Shape(ok: true, reversals: own, why: nil, wanders: true)
    }
    if turns < reversals { return drifting("few turns") }
    let sweep = travel / CGFloat(turns + 1)
    let wanders = sweep < 0.8 * ext
    if wanders && (turns < wanderingReversals || sweep < 0.5 * ext) { return drifting("short sweeps") }
    if cross > 0.8 * ext { return Shape(ok: false, reversals: turns, why: "marches along") }
    return Shape(ok: true, reversals: turns, why: nil, wanders: wanders)
  }

  /// A scribble's turns and its typical sweep along its main axis (`values`), its turns counted against its own sweeps:
  /// first with `jitter` as the hysteresis, then with a third of the typical sweep found, so a wobble is no turn.
  static func drift(_ values: [CGFloat]) -> (turns: Int, sweep: CGFloat) {
    let typical = median(sweeps(values, threshold: jitter))
    let found = sweeps(values, threshold: max(jitter, 0.35 * typical))
    // The first and the last sweep are only part of one: the pen comes down and lifts mid-sweep.
    return (found.count - 1, median(Array(found.dropFirst().dropLast())))
  }

  /// The lengths of the sweeps along `values`, from the start through each turn back (by more than `threshold`) to the end.
  static func sweeps(_ values: [CGFloat], threshold: CGFloat) -> [CGFloat] {
    guard let first = values.first else { return [] }
    var dir = 0
    var (hi, lo) = (first, first)
    var ends: [CGFloat] = [first]
    for v in values {
      if dir == 0 {
        hi = max(hi, v)
        lo = min(lo, v)
        if hi - v > threshold {
          ends = [hi]
          (dir, lo) = (-1, v)
        } else if v - lo > threshold {
          ends = [lo]
          (dir, hi) = (1, v)
        }
      } else if dir > 0 {
        if v > hi {
          hi = v
        } else if hi - v > threshold {
          ends.append(hi)
          (dir, lo) = (-1, v)
        }
      } else if v < lo {
        lo = v
      } else if v - lo > threshold {
        ends.append(lo)
        (dir, hi) = (1, v)
      }
    }
    if dir != 0 { ends.append(dir > 0 ? hi : lo) }
    return zip(ends, ends.dropFirst()).map { abs($1 - $0) }
  }

  /// The middle of `values` (the upper one of two), 0 for none.
  static func median(_ values: [CGFloat]) -> CGFloat {
    values.isEmpty ? 0 : values.sorted()[values.count / 2]
  }

  public struct Outcome: Equatable, Sendable {
    public var ok: Bool
    /// The strokes that go with the zigzag, in the board's order. Empty when it isn't a scratch-out.
    public var gone: [String]
    public var reversals: Int
    /// Board points per millisecond, to two places; nil when the time wasn't known.
    public var speed: Double?
    /// Why it stays ink: the shape's reason, or slow, no ink, beside ink; for a scribble that wanders, "wanders, no ink"
    /// or "wanders, beside ink", which stay ink unsaid.
    public var why: String?

    /// A scratch-out in shape and speed that found nothing to erase: no ink under it, or only ink beside it (#1000,
    /// stories 1051, 1052). It goes, with a word; writing that only looks like a zigzag (slow, marches along...) stays ink.
    public var findsNothing: Bool { !ok && (why == "no ink" || why == "beside ink") }
  }

  /// After the board takes back PaperKit's newest step for a zigzag (#966, #999): whether the step it took was another
  /// one, to be redone. It was the zigzag's when the zigzag is gone (`zigzagHeld` false) and the rest of the ink (`held`,
  /// by stroke) is what it was before the zigzag; a step that added or took ink, or one that only moved it, leaving
  /// every stroke's key as it was (a lasso move, context-grabber-geaz), leaves the zigzag on the board.
  public static func redoTakeBack(could: Bool, zigzagHeld: Bool, held: Set<String>, before: Set<String>) -> Bool {
    could && (zigzagHeld || held != before)
  }

  /// A fast zigzag across `box`, five sweeps along its longer side, and the milliseconds it takes: what the simulator's UI
  /// tests draw in place of a straight stroke (`GRABBER_WHITEBOARD_ZIGZAG`, #999), as XCUITest can only drag straight.
  public static func zigzag(across box: CGRect) -> (points: [CGPoint], ms: Double) {
    let along = max(box.width, box.height, 40)
    let wide = box.width >= box.height
    let mid = CGPoint(x: box.midX, y: box.midY)
    var points: [CGPoint] = []
    for i in 0..<60 {
      let t = CGFloat(i) / 59 * 5
      let sweep = Int(t)
      let f = t - CGFloat(sweep)
      let a = (sweep % 2 == 0 ? f : 1 - f) - 0.5
      let b = (t / 5 - 0.5) * 16
      points.append(wide ? CGPoint(x: mid.x + a * along, y: mid.y + b) : CGPoint(x: mid.x + b, y: mid.y + a * along))
    }
    return (points, 100)
  }

  /// The least speed, in board points per millisecond, a zigzag `length` points long (its box's longer side) is held to:
  /// `speed` from `fullSpeedLength` up, in proportion below it (cockpit-9g1, story 1283).
  public static func speedFloor(length: CGFloat) -> Double {
    speed * Double(min(1, max(0, length) / fullSpeedLength))
  }

  static func speedFloor(of points: [CGPoint]) -> Double {
    let own = box(points)
    return speedFloor(length: max(own.width, own.height))
  }

  /// A zigzag fast enough to be a scratch-out, whatever is under it: over a fold's marker there is no ink, and the fold
  /// goes all the same (story 903).
  public static func isZigzag(_ points: [CGPoint], ms: Double?) -> Bool {
    guard shape(points).ok else { return false }
    guard let speed = Self.speed(of: points, ms: ms) else { return true }
    return speed >= speedFloor(of: points)
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
    if let speed, speed < speedFloor(of: points) { return no("slow") }
    let hits = touched(by: points, in: ink)
    // A wandering scribble over nothing, or beside ink, is hatching or writing: it stays ink, unsaid (4kj).
    guard !hits.isEmpty else { return no(shape.wanders ? "wanders, no ink" : "no ink") }
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
    if all > 0, Double(inside) / Double(all) < over { return no(shape.wanders ? "wanders, beside ink" : "beside ink") }
    return Outcome(
      ok: true, gone: hits + enclosed(by: points, in: zone, taking: taken, of: ink), reversals: shape.reversals,
      speed: speed,
      why: nil)
  }

  /// The strokes the zigzag doesn't touch that lie wholly within the outline round it and the ink it `taken` (their
  /// convex hull) and within the zigzag's own `zone`, both grown by the reach a sweep has: a mark between two sweeps,
  /// a dot or a crossbar inside the struck word, never ink a long touched stroke stretched the outline over
  /// (cockpit-9g1, stories 1282, 1266). In the board's order.
  static func enclosed(by points: [CGPoint], in zone: CGRect, taking taken: Set<String>, of ink: [Ink]) -> [String] {
    let outline = hull(points + ink.filter { taken.contains($0.id) }.flatMap(\.points))
    guard outline.count >= 3 else { return [] }
    return ink.filter { stroke in
      guard !taken.contains(stroke.id), !stroke.points.isEmpty else { return false }
      let pad = reach + stroke.width / 2
      let near = zone.insetBy(dx: -pad, dy: -pad)
      return stroke.points.allSatisfy { within($0, near) && inHull($0, outline, grownBy: pad) }
    }.map(\.id)
  }

  /// The convex hull of `points`, counterclockwise in board space (y down), by the monotone chain.
  static func hull(_ points: [CGPoint]) -> [CGPoint] {
    let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    guard sorted.count >= 3 else { return sorted }
    func turn(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    func chain(_ run: [CGPoint]) -> [CGPoint] {
      var out: [CGPoint] = []
      for p in run {
        while out.count >= 2, turn(out[out.count - 2], out[out.count - 1], p) <= 0 { out.removeLast() }
        out.append(p)
      }
      return out
    }
    let lower = chain(sorted)
    let upper = chain(sorted.reversed())
    return Array(lower.dropLast() + upper.dropLast())
  }

  /// Inside the convex `outline` (from `hull`), or within `pad` of its edge.
  static func inHull(_ p: CGPoint, _ outline: [CGPoint], grownBy pad: CGFloat) -> Bool {
    let edges = zip(outline, outline.dropFirst() + [outline[0]])
    if edges.allSatisfy({ a, b in (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= 0 }) { return true }
    return edges.contains { a, b in toSegment(p, a, b) <= pad }
  }

  /// The strokes a line along `path` touches within `reach` of their own line (half the pen added): whole strokes, as
  /// the stroke eraser takes them.
  static func touched(by path: [CGPoint], in ink: [Ink]) -> [String] {
    guard let first = path.first else { return [] }
    let line = path.count > 1 ? path : [first, first]
    let pathBox = box(line)
    return ink.filter { stroke in
      guard !stroke.points.isEmpty else { return false }
      let pad = reach + stroke.width / 2
      let own = box(stroke.points)
      guard
        pathBox.maxX >= own.minX - pad, pathBox.minX <= own.maxX + pad, pathBox.maxY >= own.minY - pad,
        pathBox.minY <= own.maxY + pad
      else { return false }
      // Each stretch on its own: never a line across a gap the pixel eraser left (context-grabber-p5hy).
      for run in stroke.runs {
        guard let start = run.first else { continue }
        let points = run.count > 1 ? run : [start, start]
        for (a, b) in zip(points, points.dropFirst()) {
          for (c, d) in zip(line, line.dropFirst()) where distance(a, b, c, d) <= pad { return true }
        }
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
