//  Chat's launch hooks (docs/TESTING.md); `ChatSendHook` in ContextCore reads the two with a grammar. What a Chat
//  screen taps by itself once it shows is `LaunchHooks.current.chat`, read where it happens.

import ContextCore
import Foundation

extension AppModel {
  /// Chat: "<thread>|<text>" written in that thread as the compose bar would ("new|<text>" starts one).
  func runChatSendHook(_ hook: ChatSendHook) {
    var draft = InboxDraft()
    draft.text = hook.body
    do {
      try chat.send(&draft, thread: hook.thread)
    } catch {
      log.event("error", ["where": "chat_hook", "message": "\(error)"])
    }
  }

  /// #633: "<thread>|<path>" attached and sent as the bar would; the document picker can't be driven from a script.
  func runChatSendFileHook(_ hook: ChatSendHook) {
    do {
      var draft = InboxDraft()
      if case .file(let file) = try ChatFile.read(URL(fileURLWithPath: hook.body)) { draft.file = file }
      try chat.send(&draft, thread: hook.thread)
    } catch let problem as ChatFile.Problem {
      log.event("error", problem.logFields.merging(["where": "chat_hook"]) { _, new in new })
    } catch {
      log.event("error", ["where": "chat_hook", "message": "\(error)"])
    }
  }

  /// Story 489: every refused file sent again, as a tap on its Send again would.
  func runChatSendAgainHook() {
    inbox.reload()
    for item in inbox.items where item.canSendAgain { inbox.sendAgain(item) }
  }

  /// #536: Chat with its + already tapped, a new thread on screen; #637: `voice`, the button beside it.
  func runChatNewHook(voice: Bool) {
    openInbox(from: "hook")
    chat.openNewChat(from: "hook", voice: voice)
  }
}
