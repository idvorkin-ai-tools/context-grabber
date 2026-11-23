//  Check 6 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; story 1255): after an Undo the board is as
//  it was before the step it took back, and after a Redo as it was after it. Undo takes back the newest named step not
//  yet taken back; a name that differs is an Undo of another step. The surface's own observation that what it put
//  back drew whole is judged here too (bead 9bll).

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
        let diff = differs(want, got)
        if !diff.isEmpty {
          ids += diff.map(\.id)
          what.append("\(diff.count) differ")
          evidence += diff.prefix(5).map { Evidence($0.id, $0.how) }
        }
        let folds = Set(want.folds.keys).union(got.folds.keys).sorted().filter { want.folds[$0] != got.folds[$0] }
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
