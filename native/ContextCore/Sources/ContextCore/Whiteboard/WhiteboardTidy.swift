//  Tidy overlaps (spec 2026-11-01-whiteboard-shapes-design.md, *Keep all and Tidy overlaps*; story 896). Ported from
//  the Cockpit's web board (`tidy` in assets/ink/board.mjs); Keep all no longer lays labels out (context-grabber-yqau). The
//  web board makes room by pushing the ink below down; the iPad never moves his ink, so a label that would sit on ink
//  moves down to the first clear space under it instead. Board points throughout; the app hands in the ink as points
//  and moves what this names.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum WhiteboardTidy {
  /// The air left between ink and a label moved under it: half a ruled line, as on the web board.
  public static let air: CGFloat = 20

  /// How far down `box` moves to sit on no ink: 0 when no point of `ink` lies inside it (touching is fine). Each time
  /// it lands on ink it moves under the lowest of that ink across its width, with `air`, until it sits clear.
  public static func clearing(_ box: CGRect, of ink: [[CGPoint]]) -> CGFloat {
    guard !box.isNull, box.width > 0 || box.height > 0 else { return 0 }
    var dy: CGFloat = 0
    // Each move is more than `air` down, and the ink ends somewhere: this always stops.
    while true {
      let at = box.offsetBy(dx: 0, dy: dy)
      var bottom: CGFloat?
      for stroke in ink where stroke.contains(where: { inside($0, at) }) {
        let across = stroke.filter { $0.x > at.minX && $0.x < at.maxX }.map(\.y)
        bottom = max(bottom ?? -.infinity, across.max() ?? at.minY)
      }
      guard let bottom else { return dy }
      dy = bottom + air - box.minY
    }
  }

  /// Tidy: kept labels that sit on other ink, his or a label's above, are laid out again top to bottom, each moved
  /// under what it sits on, as a kept label is. `labels` by id; `ink` is everything else. How far each moved one goes;
  /// one that sits clear isn't named.
  public static func tidy(_ labels: [String: [[CGPoint]]], among ink: [[CGPoint]]) -> [String: CGFloat] {
    let ink = ink.map(dense)
    let labels = labels.mapValues { $0.map(dense) }
    let order = labels.keys.sorted { a, b in
      let (p, q) = (bounds(labels[a] ?? []), bounds(labels[b] ?? []))
      return p.minY != q.minY ? p.minY < q.minY : p.minX != q.minX ? p.minX < q.minX : a < b
    }
    var moves: [String: CGFloat] = [:]
    for (i, id) in order.enumerated() {
      // The labels above, where they now are; the ones below are laid out after it.
      let others = order.prefix(i).flatMap { other in
        (labels[other] ?? []).map { line in line.map { CGPoint(x: $0.x, y: $0.y + (moves[other] ?? 0)) } }
      }
      let dy = clearing(bounds(labels[id] ?? []), of: ink + others)
      if dy > 0 { moves[id] = dy }
    }
    return moves
  }

  /// A line with a point at least every 4 board points, so ink crossing a box between two of its points is seen.
  static func dense(_ line: [CGPoint]) -> [CGPoint] {
    guard let first = line.first else { return [] }
    var out = [first]
    for (a, b) in zip(line, line.dropFirst()) {
      let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 4).rounded(.up)))
      for k in 1...steps {
        let t = CGFloat(k) / CGFloat(steps)
        out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
      }
    }
    return out
  }

  /// The lines' box; null for none.
  public static func bounds(_ lines: [[CGPoint]]) -> CGRect {
    WhiteboardMarkChoice.bounds(lines)
  }

  /// Strictly inside: ink that only touches the box's edge is not under it.
  static func inside(_ p: CGPoint, _ box: CGRect) -> Bool {
    p.x > box.minX && p.x < box.maxX && p.y > box.minY && p.y < box.maxY
  }
}
