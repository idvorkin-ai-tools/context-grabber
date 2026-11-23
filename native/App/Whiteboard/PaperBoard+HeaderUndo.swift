//  Bead context-grabber-ssl (story 1179; spec 2026-11-16-whiteboard-board-ops-design.md, *Headers fold their
//  sections*): a header made or unmade alone, by a margin tap or the hold menu, changes no ink, so the markup's Undo
//  can't take it back. It is its own step: the board's headers and declined lines as they were, and Redo as they are.

import ContextCore
import UIKit

/// The board's headers and the lines declined as headers (story 1034), as one Undo step puts them back.
struct BoardHeaderState: Equatable {
  var headers: [BoardHeader]
  var declined: Set<String>
}

extension WhiteboardModel {
  var headerState: BoardHeaderState { BoardHeaderState(headers: headers, declined: declined) }

  /// An Undo or Redo of a header change: the headers and declined lines as `state` has them, kept on the board.
  func restoreHeaders(_ state: BoardHeaderState) {
    if headers != state.headers {
      headers = state.headers
      opLedger.setHeaders(headers, board: board.id)
    }
    if declined != state.declined {
      declined = state.declined
      opLedger.setDeclined(declined, board: board.id)
    }
  }
}

extension PaperBoardController {
  /// One Undo named `name` back to `state`; its Redo comes back to the headers as they are now. `withInk` is a step
  /// grouped with the ink's own, which tells Larry of the Undo, so this one doesn't say it again.
  func registerHeaderStep(back state: BoardHeaderState, named name: String, withInk: Bool) {
    guard let undo = paper.undoManager else { return }
    stepsOn = undo
    undo.registerUndo(withTarget: self) { controller in
      MainActor.assumeIsolated { controller.stepHeaders(to: state, named: name, withInk: withInk) }
    }
    undo.setActionName(name)
  }

  private func stepHeaders(to state: BoardHeaderState, named name: String, withInk: Bool) {
    // #966: the board's take-back of PaperKit's step reached this one; its Redo puts it straight back, unsaid.
    let probed = probe.reached(name)
    let undoing = paper.undoManager?.isUndoing == true
    registerHeaderStep(back: model.headerState, named: name, withInk: withInk)
    model.restoreHeaders(state)
    showMarks()
    guard !probed else { return }
    if undoing && !withInk { model.undid(name) }
    log.event(
      "board_outline",
      [
        "action": undoing ? "header_undo" : "header_redo", "board": model.board.id, "label": name,
        "headers": state.headers.count, "declined": state.declined.count,
      ])
  }
}
