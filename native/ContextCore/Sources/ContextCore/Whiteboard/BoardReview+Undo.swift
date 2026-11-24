//  Check 6 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; story 1255): after an Undo the ink and
//  folds the step it took back touched are as they were before it, and after a Redo as they were after it; ink it
//  never touched is not judged. Undo takes back the newest named step not yet taken back; a name that differs is an
//  Undo of another step. The surface's own observation that what it put back drew whole is judged here too (bead
//  9bll).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension BoardReview {
  static func undoRestored(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    var undoable: [[Int]] = []
    var redoable: [[Int]] = []
    for group in pass.groups {
      let i = group[0]
      let step = pass.steps[i]
      switch step.kind {
      case "undo", "redo":
        let isUndo = step.kind == "undo"
        guard let target = isUndo ? undoable.popLast() : redoable.popLast() else { continue }
        if isUndo { redoable.append(target) } else { undoable.append(target) }
        let want = isUndo ? pass.states[target[0]] : pass.settled(target)
        let got = pass.settled(group)
        let targetStep = pass.steps[target[0]]
        var evidence = [Evidence("took back", "step \(target[0]) \(targetStep.kind) \(targetStep.name ?? "")")]
        var ids: [String] = []
        var what: [String] = []
        if let name = step.name, let named = targetStep.name, name != named {
          what.append("its name \(name) is not the step's \(named)")
        }
        let touched = Set(target.flatMap { pass.steps[$0].changes ?? [] }.map(\.id))
          .union(target.flatMap { pass.steps[$0].fold.map { [$0.header] + $0.held } ?? [] })
        let headers = Set(target.compactMap { pass.steps[$0].fold?.header })
        let diff = differs(want, got).filter { touched.contains($0.id) }
        if !diff.isEmpty {
          ids += diff.map(\.id)
          what.append("\(diff.count) differ")
          evidence += diff.prefix(5).map { Evidence($0.id, $0.how) }
        }
        let folds = headers.sorted().filter { foldShown(want.folds[$0]) != foldShown(got.folds[$0]) }
        if !folds.isEmpty {
          what.append("folds differ")
          evidence.append(Evidence("folds", folds.joined(separator: ", ")))
        }
        if step.seen?.drawnWhole == false {
          what.append("what it put back did not draw whole")
          evidence.append(Evidence("drawn", "not whole after the surface's redraws"))
          ids += (step.changes ?? []).map(\.id)
        }
        if !what.isEmpty {
          out.append(
            pass.finding(
              6, .bug, step: i, story: 1255, ids: Array(Set(ids)),
              "\(isUndo ? "Undo" : "Redo") of \(targetStep.name ?? targetStep.kind) didn't restore the board: "
                + what.joined(separator: "; "), evidence))
        }
      default:
        if step.name != nil, step.kind != "apart" {
          undoable.append(group)
          redoable = []
        }
      }
    }
    return out
  }

  /// What a fold shows: the ink it hides while folded, nil while open.
  static func foldShown(_ fold: FoldState?) -> Set<String>? {
    guard let fold, fold.folded else { return nil }
    return fold.held
  }

  /// The units whose presence, place or hiding differ between two boards.
  static func differs(_ want: State, _ got: State) -> [(id: String, how: String)] {
    Set(want.units.keys).union(got.units.keys).sorted().compactMap { id in
      switch (want.units[id], got.units[id]) {
      case (nil, nil): return nil
      case (let a?, nil): return (id, "missing, was \(box(a.box))")
      case (nil, let b?): return (id, "there, wasn't: \(box(b.box))")
      case (let a?, let b?):
        if moved(a.box, b.box) { return (id, "at \(box(b.box)), was \(box(a.box))") }
        if a.hidden != b.hidden { return (id, b.hidden ? "hidden, was showing" : "showing, was hidden") }
        return nil
      }
    }
  }
}
