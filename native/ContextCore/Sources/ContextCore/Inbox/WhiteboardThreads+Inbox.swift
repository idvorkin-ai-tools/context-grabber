//  The board's thread and the Inbox's outbox together: it stays in ContextCore, which owns `InboxItem`, while
//  `WhiteboardThreads` sits in the board's module below (plan 2026-11-22-contextcore-targets-plan.md).

import Foundation

extension WhiteboardThreads {
  /// The board has no thread yet and a picture waiting in the outbox will start it.
  public func firstSendWaiting(board: String, in items: [InboxItem]) -> Bool {
    thread(board: board) == nil && items.contains { $0.whiteboard?.board == board && $0.status == .waiting }
  }
}
