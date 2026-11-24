//  Check 5 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; story 1254): a fold hides its section and
//  nothing else. Ink written under a header while it was folded stays out when it folds again (story 1231), ink written
//  into the open section joins it, and a fold again hides nothing older that the last one didn't (story 1232).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension BoardReview {
  static func foldSwallowed(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    for (i, step) in pass.steps.enumerated() where step.kind == "fold" {
      guard let fold = step.fold, fold.folded ?? true else { continue }
      let before = pass.states[i]
      let after = pass.states[i + 1]
      guard let last = before.folds[fold.header] else { continue }
      let extra = Set(fold.held).subtracting(last.held)
      guard !extra.isEmpty else { continue }
      let writtenFolded = Set(
        (0..<i).flatMap { j in
          pass.states[j].folds[fold.header]?.folded == true
            ? (pass.steps[j].changes ?? []).filter { $0.before == nil && $0.after != nil }.map(\.id) : []
        })
      let newer = extra.filter { writtenFolded.contains($0) }
      let older = extra.filter { id in
        guard let added = after.units[id]?.added else { return true }
        return last.at.map { added <= $0 } ?? false
      }
      let ids = Array(newer.isEmpty ? older : newer)
      guard !ids.isEmpty else { continue }
      let boxes = ids.compactMap { after.units[$0]?.box }
      let times = ids.compactMap { after.units[$0]?.added }
      var evidence = [
        Evidence("header", fold.header),
        Evidence(
          "held", "\(strokes(Array(last.held), in: before)) at its last fold, \(strokes(fold.held, in: after)) now"),
        Evidence("extra", "\(many(strokes(ids, in: after))): \(list(ids))"),
        Evidence("box", union(boxes).map(box) ?? "none"),
      ]
      if let first = times.min(), let lastT = times.max() {
        evidence.append(Evidence("written", "\(num(first))..\(num(lastT))"))
      }
      out.append(
        pass.finding(
          5, .bug, step: i, story: newer.isEmpty ? 1232 : 1231, ids: ids,
          newer.isEmpty
            ? "folding \(fold.header) again hid \(many(strokes(ids, in: after))) its last fold didn't"
            : "folding \(fold.header) hid \(many(strokes(ids, in: after))) written while it was folded", evidence))
    }
    return out
  }
}
