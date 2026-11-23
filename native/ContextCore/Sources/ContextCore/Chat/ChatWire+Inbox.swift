//  The part of the chat wire that reads the Inbox: it stays in ContextCore, which owns `InboxItem`, while the rest
//  of `ChatWire` sits in its own module below (plan 2026-11-22-contextcore-targets-plan.md).

import Foundation

extension ChatWire {
  /// What only the list can show of what has not reached a thread: a new chat, or a message for a chat the list does
  /// not hold, so no thread on screen can show it (a share into a chat that has gone, #587).
  public static func pendingThreads(_ items: [InboxItem], listed threads: [ChatSummary]) -> [InboxItem] {
    let keys = Set(threads.map(\.key))
    return items.filter { item in item.status != .sent && item.thread.map { !keys.contains($0) } ?? true }
  }
}
