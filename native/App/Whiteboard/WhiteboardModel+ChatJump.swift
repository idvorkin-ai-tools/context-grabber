//  Bead context-grabber-dbku, story 1206 (spec: native chat, *Between a board and its chat*): a look at the board's thread
//  doesn't close the board. While the thread is slid in over it the board is saved and quiet; Back finds it as he left
//  it, a held change of Larry's still waiting and a new empty board still there.

import Foundation

extension WhiteboardModel {
  /// The thread slid in over the board: what is drawn is saved now, the mic stops, and nothing closes.
  func setAsideForChat() {
    asideForChat = true
    flush()
    stopMic(why: "chat")
    log.event("whiteboard", ["action": "aside_for_chat", "board": board.id, "strokes": drawing.strokes.count])
  }

  /// The board is on screen again.
  func backFromChat() {
    guard asideForChat else { return }
    asideForChat = false
    log.event("whiteboard", ["action": "back_from_chat", "board": board.id])
  }

  /// The thread over the board has gone without pushing anything of its own: popped back to the board, which is back
  /// on screen within a moment, or taken down with it, which closes the board as leaving it does.
  func chatLeftOverBoard() {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(800))
      guard let self, self.asideForChat else { return }
      self.asideForChat = false
      self.log.event("whiteboard", ["action": "closed_under_chat", "board": self.board.id])
      self.endPlayback()
      self.close()
    }
  }
}
