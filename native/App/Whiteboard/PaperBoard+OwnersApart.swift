//  A board on paper: a move the system made on its own (PaperKit's handwriting reflow above all) never carries Igor's ink
//  and Larry's or Claude's together (story 1145, bead context-grabber-eg7v). The owner with more of the moved strokes keeps
//  the move; the other's go back where they were, in one Undo with the move, through the board's edit lane.

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Story 1145: what the rule made of `change`, for the change's log line; a split is put right once PaperKit's own
  /// callback is over. `previous`: the strokes' frames before the change.
  func keepOwnersApart(
    _ change: PaperProbe.InkChange, markup: PaperMarkup, previous: [String: CGRect], undo: UndoManager?
  ) -> [String: Any] {
    guard !change.moved.isEmpty else { return [:] }
    guard drawsHere, change.added.isEmpty, change.removed.isEmpty, undo?.isUndoing != true, undo?.isRedoing != true
    else { return ["apart": "not_a_move"] }
    let held = (run?.heldAtStart ?? []).union(paper.selection.map(Self.key))
    let apart = PaperProbe.ownersApart(change.moved, held: held, theirs: theirKeys(markup))
    var fields: [String: Any] = ["apart": apart.verdict.rawValue]
    guard apart.verdict == .split else { return fields }
    let whose = apart.putBackTheirs ? "theirs" : "mine"
    fields.merge(["apart_back": apart.putBack.count, "apart_back_whose": whose]) { $1 }
    let moves = change.moved
    // Not from inside PaperKit's own callback, as a drop's room isn't.
    Task { @MainActor [weak self] in
      self?.putOwnerBack(apart.putBack, whose: whose, reflowed: markup, previous: previous, moves: moves)
    }
    return fields
  }

  /// PaperKit's step for the move taken back, and the moving owner's strokes put where it took them, as one step back to
  /// before the move. When the step taken back wasn't the move's (the board then is not as it was before it), that undo is
  /// redone and the other owner's strokes are moved back by what they moved instead.
  private func putOwnerBack(
    _ back: Set<String>, whose: String, reflowed: PaperMarkup, previous: [String: CGRect], moves: [PaperProbe.InkMove]
  ) {
    var event: [String: Any] = [
      "action": "paper_apart", "board": model.board.id, "back": back.count, "whose": whose, "moved": moves.count,
      "in_touch": run != nil,
    ]
    let framesBefore = inkFrames
    let tookBack = quietly { takeBackPaperKitsStep(why: "apart") }
    let restored = paper.markup
    let clean = tookBack && (restored.map { Self.close($0.strokeFrames, previous) } ?? false)
    event["took_back"] = tookBack
    event["undid_move"] = clean
    var result: PaperMarkup
    if clean, let restored {
      // The board before the move, with the moving owner's strokes as the move left them.
      result = restored
      let moving = Set(moves.map(\.id)).subtracting(back)
      for element in reflowed.subelements.strokes where moving.contains(Self.key(element.elementID)) {
        _ = result.subelements.updateOrAppend(element)
      }
      registerStepBack(to: restored, named: "Move")
      event["how"] = "took_back"
    } else {
      if tookBack { quietly { paper.undoManager?.redo() } }
      result = paper.markup ?? reflowed
      let by = Dictionary(uniqueKeysWithValues: moves.map { ($0.id, $0) })
      for element in result.subelements.strokes {
        guard back.contains(Self.key(element.elementID)), let move = by[Self.key(element.elementID)] else { continue }
        var stroke = element
        stroke.applyTransform(CGAffineTransform(translationX: -move.dx, y: -move.dy))
        _ = result.subelements.updateOrAppend(stroke)
      }
      event["how"] = "moved_back"
    }
    let held = setMarkup(result, named: "apart").held
    inkFrames = held.strokeFrames
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    let went = back.filter { key in
      guard let was = previous[key], let now = inkFrames[key] else { return false }
      return abs(was.minX - now.minX) + abs(was.minY - now.minY) + abs(was.width - now.width)
        + abs(was.height - now.height) < 0.5
    }
    event["back_in_place"] = went.count
    event["can_undo"] = paper.undoManager?.canUndo ?? false
    event["undo_name"] = paper.undoManager?.undoActionName ?? ""
    log.event("whiteboard", event)
    showMarksSoon()
    redrawSoon()
  }
}
