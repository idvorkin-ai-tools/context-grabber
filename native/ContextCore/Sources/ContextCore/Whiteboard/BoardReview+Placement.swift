//  Checks 1 and 2 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; stories 1250, 1251): new writing
//  that landed inside a fold, and what the board placed that landed on ink already showing, against the room the drop
//  rule (`BoardRoom.drop`) calls for.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardReview {
  /// What the board places, as opposed to Igor's own pen.
  static let placing: Set<String> = ["paste", "drop", "keep", "text", "late"]

  /// Check 1: ink a step added shows after it, and no fold grew by it without a fold step. Ink on a folded header's
  /// own line joins the header and is no finding.
  static func insideFold(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    for (i, step) in pass.steps.enumerated() where !["fold", "unfold", "undo", "redo"].contains(step.kind) {
      let before = pass.states[i]
      let after = pass.states[i + 1]
      let added = (step.changes ?? []).filter { $0.before == nil && $0.after != nil }.map(\.id)
      guard !added.isEmpty else { continue }
      var swallowed: [String] = []
      var into: String?
      for id in added {
        guard let unit = after.units[id] else { continue }
        let grownInto = after.folds.keys.sorted().first { header in
          (after.folds[header]?.held.contains(id) ?? false) && !(before.folds[header]?.held.contains(id) ?? false)
        }
        guard unit.hidden || grownInto != nil else { continue }
        let foldedHeaders = after.folds.filter { $0.value.folded }.keys.sorted()
        let onHeaderLine = foldedHeaders.contains { header in
          guard let line = after.units[header]?.box else { return false }
          let mid = unit.box.y + unit.box.h / 2
          return mid >= line.y && mid <= line.maxY
        }
        if onHeaderLine { continue }
        swallowed.append(id)
        into = into ?? grownInto ?? foldedHeaders.first { after.folds[$0]?.held.contains(id) ?? false }
      }
      guard !swallowed.isEmpty else { continue }
      let n = strokes(swallowed, in: after)
      var evidence = [
        Evidence("new", "\(many(n)): \(list(swallowed))"),
        Evidence("box", union(swallowed.compactMap { after.units[$0]?.box }).map(box) ?? "none"),
      ]
      if let into {
        evidence.append(Evidence("header", into))
        evidence.append(
          Evidence(
            "fold held",
            "\(strokes(Array(before.folds[into]?.held ?? []), in: before)) before, "
              + "\(strokes(Array(after.folds[into]?.held ?? []), in: after)) after"))
      }
      out.append(
        pass.finding(
          1, .bug, step: i, story: 1250, ids: swallowed,
          "\(many(n)) of new ink went into the fold\(into.map { " under \($0)" } ?? "") as they landed", evidence))
    }
    return out
  }

  /// Check 2: what the board placed lands on no ink that showed before the step, once the step has settled.
  static func underInk(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    for group in pass.groups {
      let i = group[0]
      let step = pass.steps[i]
      guard placing.contains(step.kind) else { continue }
      let before = pass.states[i]
      let after = pass.settled(group)
      let aimed = Set(step.aim?.ids ?? [])
      var placed = Set<String>()
      for change in step.changes ?? [] where change.after != nil {
        if change.before == nil || aimed.contains(change.id) { placed.insert(change.id) }
      }
      guard !placed.isEmpty else { continue }
      let others = before.units.keys.filter { !placed.contains($0) && before.showing($0) && after.showing($0) }
      var under: [String] = []
      for id in others.sorted() {
        guard let o = after.units[id]?.box else { continue }
        if placed.contains(where: { p in after.units[p].map { meet($0.box, o) } ?? false }) { under.append(id) }
      }
      guard !under.isEmpty else { continue }
      let placedIDs = Array(placed)
      // Story 1318: a drop Igor dragged himself that only grazes ink is as designed; what the board placed is strict.
      let deepest = deepestOverlap(placed, under, in: after)
      let grazed = byHand.contains(step.by) && step.kind == "drop" && deepest.depth <= deepest.allowance
      var evidence = [
        Evidence("placed", "\(many(strokes(placedIDs, in: after))): \(list(placedIDs))"),
        Evidence("at", union(placedIDs.compactMap { after.units[$0]?.box }).map(box) ?? "none"),
        Evidence(
          "on",
          under.prefix(5).compactMap { id in after.units[id].map { "\(id) (\($0.owner)) \(box($0.box))" } }
            .joined(separator: "; ")),
      ]
      if step.kind == "drop" {
        let rule = dropRoom(pass, group)
        evidence.append(
          Evidence("room the rules call for", rule.predicted.map { "\(num($0.dy)) at \(num($0.cut))" } ?? "none"))
        evidence.append(Evidence("room that opened", rule.opened.map { "\(num($0))" } ?? "none"))
      }
      if byHand.contains(step.by) && step.kind == "drop" {
        evidence.append(
          Evidence("overlap", "\(num(deepest.depth)) pt, \(num(deepest.allowance)) allowed for a drop by hand"))
      }
      if grazed {
        out.append(
          pass.finding(
            2, .asDesigned, step: i, story: 1318, ids: placedIDs,
            "a drop he dragged himself grazed \(many(strokes(under, in: after))) by \(num(deepest.depth)) pt", evidence)
        )
        continue
      }
      out.append(
        pass.finding(
          2, .bug, step: i, story: 1251, ids: placedIDs,
          "a \(step.kind) landed on \(many(strokes(under, in: after))) that were showing", evidence))
    }
    return out
  }

  /// Who drags by hand: a drop of theirs that only grazes ink is as designed (story 1318).
  static let byHand: Set<String> = ["pencil", "finger"]

  /// A drop by hand may overlap ink by this much: 4 pt, or 15% of the shorter box's height when that is more
  /// (story 1318, Larry and Igor 2026-11-24).
  static func dragAllowance(_ a: Box, _ b: Box) -> Double { max(4, 0.15 * min(a.h, b.h)) }

  /// The deepest overlap between what was placed and the ink it landed on (the lesser of the two axes' overlaps,
  /// how far it would have to move to clear), with the allowance of that pair.
  static func deepestOverlap(_ placed: Set<String>, _ under: [String], in state: State) -> (
    depth: Double, allowance: Double
  ) {
    var deepest = (depth: 0.0, allowance: 0.0)
    for p in placed.sorted() {
      guard let a = state.units[p]?.box else { continue }
      for o in under {
        guard let b = state.units[o]?.box else { continue }
        let depth = min(min(a.maxX, b.maxX) - max(a.x, b.x), min(a.maxY, b.maxY) - max(a.y, b.y))
        if depth > deepest.depth { deepest = (depth, dragAllowance(a, b)) }
      }
    }
    return deepest
  }

  /// The room `BoardRoom.drop` calls for when the aimed ink is dropped, and the room that opened: how far the ink
  /// below that wasn't dropped went down.
  static func dropRoom(_ pass: Pass, _ group: [Int]) -> (predicted: (cut: Double, dy: Double)?, opened: Double?) {
    let i = group[0]
    let step = pass.steps[i]
    let before = pass.states[i]
    let after = pass.settled(group)
    let aimed = Set(step.aim?.ids ?? [])
    guard let from = union(aimed.compactMap { before.units[$0]?.box }),
      let block = union(aimed.compactMap { after.units[$0]?.box })
    else { return (nil, nil) }
    let among = before.units.filter { !aimed.contains($0.key) && !$0.value.hidden }.keys.sorted().compactMap {
      before.units[$0].map { rect($0.box) }
    }
    let push = BoardRoom.drop(rect(block), from: rect(from), among: among)
    var opened: Double?
    for (id, unit) in before.units where !aimed.contains(id) {
      guard let now = after.units[id]?.box else { continue }
      let dy = now.y - unit.box.y
      if dy > tolerance { opened = max(opened ?? 0, dy) }
    }
    return (push.map { (Double($0.cut), Double($0.dy)) }, opened)
  }

  static func rect(_ b: Box) -> CGRect {
    CGRect(x: CGFloat(b.x), y: CGFloat(b.y), width: CGFloat(b.w), height: CGFloat(b.h))
  }
}
