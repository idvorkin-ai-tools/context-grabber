//  Bead context-grabber-dbku, story 1223 (spec: native chat, *Between a board and its chat*): a look at the board's thread
//  doesn't close the board. While the thread is slid in over it the board is saved and quiet; Back finds it as he left
//  it, a held change of Larry's still waiting and a new empty board still there.

import ContextCore
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
    chatCover.uncovered()
    guard asideForChat else { return }
    asideForChat = false
    log.event("whiteboard", ["action": "back_from_chat", "board": board.id])
  }

  /// A screen over the board, its thread or anything pushed above that, has come on screen.
  func coverAppeared(_ screen: String) { chatCover.appeared(screen) }

  /// A screen over the board has gone. When it was the last one over it, the board is either back on screen within a
  /// moment or was taken down with everything over it, which closes the board as leaving it does.
  func coverLeft(_ screen: String) {
    guard chatCover.lastOver(screen) else { return }
    Task { @MainActor [self] in
      try? await Task.sleep(for: .milliseconds(800))
      guard asideForChat, chatCover.lastOver(screen) else { return }
      asideForChat = false
      chatCover.uncovered()
      log.event("whiteboard", ["action": "closed_under_chat", "board": board.id])
      endPlayback()
      close()
    }
  }
}

/// Story 1223: the boards set aside under a screen, each told when that screen comes and goes.
struct BoardsUnder {
  private var boards: [WhiteboardModel] = []

  func adding(_ model: WhiteboardModel) -> BoardsUnder {
    var under = self
    under.boards.append(model)
    return under
  }

  @MainActor func appeared(_ screen: String) { boards.forEach { $0.coverAppeared(screen) } }
  @MainActor func left(_ screen: String) { boards.forEach { $0.coverLeft(screen) } }
}
