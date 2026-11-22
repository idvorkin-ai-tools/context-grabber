//  The board's settings: ghosts, grid, ruled lines, lettering and paper.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  func setGhosts(_ on: Bool) {
    UserDefaults.standard.set(on, forKey: Self.ghostsKey)
    log.event("whiteboard", ["action": on ? "ghosts_on" : "ghosts_off", "board": board.id])
    turns.setOn(on)
    if !on {
      cancelPause()
      larry.dropped()
      if micOn || micStarting {
        turns.micClosedByGhostsOff()
        stopMic(why: "ghosts_off")
      }
    }
  }

  func setRuled(_ on: Bool) {
    ruledOn = on
    log.event("whiteboard", ["action": on ? "ruled_on" : "ruled_off", "board": board.id])
    if on, gridOn { setGrid(false) }
    saveLines()
  }

  func setGrid(_ on: Bool) {
    gridOn = on
    log.event("whiteboard", ["action": on ? "grid_on" : "grid_off", "board": board.id])
    if on, ruledOn { setRuled(false) }
    saveLines()
  }

  private func saveLines() {
    BoardLines().set(gridOn ? .grid : ruledOn ? .ruled : .none, board: board.id)
  }

  /// #950: single strokes or the real font for what the board letters next; nothing already on it changes.
  func setLettering(_ new: WhiteboardTurn.LetterStyle) {
    guard editable, new != lettering else { return }
    lettering = new
    BoardLetteringChoice().set(new, board: board.id)
    log.event("whiteboard", ["action": "lettering", "board": board.id, "lettering": new.rawValue])
  }

  func setPaper(_ new: BoardPaper) {
    guard editable, new != paper else { return }
    paper = new
    store.setPaper(new, board: board.id)
    log.event("whiteboard", ["action": "paper", "board": board.id, "paper": new.rawValue])
  }
}
