//  Checks 7–9 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; stories 1256–1258, 1260): what only a
//  surface's eyes can say. A check the surface doesn't observe reads not checked; one it observes approximately (the
//  web board's pen in hand) reads approximate and never calls a bug.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension BoardReview {
  /// Check 7: a selection taken from him comes back at once (stories 946, 949), or it is a bug.
  static func selectionLost(_ pass: Pass) -> [Finding] {
    let sight = sight(7, pass.record.header.observes)
    guard sight != .notChecked else { return [] }
    return pass.steps.enumerated().compactMap { i, step in
      guard step.kind == "selection_lost" else { return nil }
      let ids = step.aim?.ids ?? []
      let n = strokes(ids, in: pass.states[i])
      let back = step.seen?.heldAfter == true
      return pass.finding(
        7, back ? .asDesigned : sight == .approximate ? .unclear : .bug, step: i, story: back ? 949 : 1256, ids: ids,
        back
          ? "a selection of \(many(n)) was taken by the \(step.by) and put back at once"
          : "a selection of \(many(n)) went with nothing of yours to end it",
        [Evidence("selection", many(n)), Evidence("held after", back ? "yes" : "no")])
    }
  }

  /// Check 8: keeping a mark leaves him the pen he held.
  static func penChanged(_ pass: Pass) -> [Finding] {
    let sight = sight(8, pass.record.header.observes)
    guard sight != .notChecked else { return [] }
    return pass.steps.enumerated().compactMap { i, step in
      guard step.kind == "keep", let was = step.seen?.penBefore, let now = step.seen?.penAfter, was != now else {
        return nil
      }
      let ids = (step.changes ?? []).map(\.id)
      return pass.finding(
        8, sight == .approximate ? .unclear : .bug, step: i, story: 1257, ids: ids,
        "keeping a mark changed your pen", [Evidence("pen before", was), Evidence("pen after", now)])
    }
  }

  /// Check 9: a kept mark draws whole and in its own colour once the surface's redraws have had their chance.
  static func keptDrawn(_ pass: Pass) -> [Finding] {
    let sight = sight(9, pass.record.header.observes)
    guard sight != .notChecked else { return [] }
    return pass.steps.enumerated().compactMap { i, step in
      guard step.kind == "keep", let looks = step.seen?.kept, let last = looks.last else { return nil }
      let bad = looks.map(keptWrong)
      guard bad.contains(where: { $0 != nil }) else { return nil }
      let ids = (step.changes ?? []).map(\.id)
      var evidence = [Evidence("looks", "\(looks.count)")]
      for (n, why) in bad.enumerated() { evidence.append(Evidence("look \(n)", why ?? "whole")) }
      if let why = keptWrong(last) {
        return pass.finding(
          9, sight == .approximate ? .unclear : .bug, step: i, story: 1258, ids: ids,
          "a kept mark drew \(why) after \(looks.count - 1) redraws", evidence)
      }
      return pass.finding(
        9, .asDesigned, step: i, story: 1258, ids: ids, "a kept mark drew cut at first and a redraw healed it",
        evidence)
    }
  }

  /// Why a look at a kept mark is wrong: under nine tenths of its span on either axis, or more dark than its colour.
  static func keptWrong(_ look: BoardSessionRecord.KeptLook) -> String? {
    if look.shown.count == 2, look.expected.count == 2,
      look.shown[0] < 0.9 * look.expected[0] || look.shown[1] < 0.9 * look.expected[1]
    {
      return "cut (\(num(look.shown[0]))x\(num(look.shown[1])) of \(num(look.expected[0]))x\(num(look.expected[1])))"
    }
    if let dark = look.darkPx, dark > (look.inkPx ?? 0) {
      return "in another colour (\(dark) dark px, \(look.inkPx ?? 0) in its colour)"
    }
    return nil
  }
}
