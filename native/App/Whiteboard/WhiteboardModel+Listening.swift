//  Larry is listening (story 929, bead context-grabber-4fww): the Cockpit's hold on Igor's newest message, read from the
//  thread the board already looks at every few seconds. The hold on the picture of the turn out is his answer; the ear
//  shows while no turn is out. What counts as a hold is ContextCore's `WhiteboardLarryListening` (host-tested).

import ContextCore
import Foundation

extension WhiteboardModel {
  /// One look at the thread (`messages`, the whole of it, oldest first): end the turn Larry is holding on, and show or
  /// clear the ear.
  func heardLarryHold(_ messages: [ChatMessage]) {
    let label = WhiteboardLarryListening.label(in: messages)
    if case .awaiting(let since, _) = larry.state, !larrySending {
      let out = larryOut.flatMap { $0.turn == larry.state ? $0 : nil }
      let looking = max(0, (ContinuousClock.now - since) / .seconds(1))
      let went = Date() - looking
      if WhiteboardLarryListening.holdsTurn(larry, thread: messages, picture: out?.picture.pictureID, went: went) {
        // Story 929: a hold is an answer, not a silence: no Interrupt, no *Larry didn't answer*, waiting ink goes.
        larryFollowUp(
          larry.replied(version: ops.rev, now: .now), why: "larry_waiting",
          facts: ["picture": out?.picture.pictureID ?? "", "looking_s": Int(looking)])
        checkLarryWait()
      }
    }
    // Off: Larry's message is the newest, or Igor's newest carries no hold (a new one went, or the Cockpit lifted it).
    let newest = messages.last { !$0.isSystem }
    let why = label != nil ? "hold" : newest.map { $0.fromIgor ? "released" : "reply" } ?? "released"
    larryListeningChanged(label, why: why, message: messages.last(where: \.fromIgor)?.id)
  }

  /// The ear's words change: published only on a change, logged on and off (`larry_listening`).
  func larryListeningChanged(_ label: String?, why: String, message: String? = nil) {
    guard label != larryListening else { return }
    let was = larryListening
    larryListening = label
    var event: [String: Any] = [
      "action": "larry_waiting", "board": board.id, "on": label != nil, "why": why,
      "label": label ?? was ?? "",
    ]
    if let message { event["message"] = message }
    log.event("whiteboard", event)
  }
}
