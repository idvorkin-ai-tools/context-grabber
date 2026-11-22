//  The board's responder, read from and written to the Cockpit (stories 659, 960).
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// Story 659: which responder the board has, asked as it opens. Until the Cockpit answers, or when it can't, Larry
  /// stays ticked: the log says so, the bar doesn't. Story 960: a board nobody ever set is given to Larry, once.
  func readResponder() async {
    let asked = responder.generation
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.readRequest(board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    var event: [String: Any] = ["action": "responder_read", "board": board.id]
    var defaulting: WhiteboardResponder?
    switch reply {
    case .responder(let answered, let set):
      responder.heard(answered, asked: asked)
      event["ok"] = true
      event["responder"] = answered.rawValue
      event["set"] = set
      // Only when nothing has been chosen here since the read went out.
      if asked == responder.generation { defaulting = WhiteboardResponder.defaulting(answered, set: set) }
    case .failed(let reason, let status):
      event["ok"] = false
      event["reason"] = reason
      if let status { event["status"] = status }
    }
    event["ticked"] = responder.shown.rawValue
    if let defaulting { event["defaulting_to"] = defaulting.rawValue }
    log.event("whiteboard", event)
    if let defaulting, let choice = responder.chose(defaulting) {
      log.event(
        "whiteboard",
        ["action": "responder", "board": board.id, "responder": defaulting.rawValue, "why": "default"])
      await writeResponder(defaulting, choice: choice)
    }
  }

  /// Story 659: Igor picked who answers the board's pauses. It shows at once and goes to the Cockpit; a write that
  /// fails takes the tick back and says why.
  func setResponder(_ new: WhiteboardResponder) {
    guard editable, let choice = responder.chose(new) else { return }
    log.event("whiteboard", ["action": "responder", "board": board.id, "responder": new.rawValue])
    Task { await writeResponder(new, choice: choice) }
  }

  private func writeResponder(_ new: WhiteboardResponder, choice: Int) async {
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.writeRequest(new, board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    switch reply {
    case .responder(let answered, _):
      responder.wrote(answered, choice: choice)
      if problem?.context == "WhiteboardView.responder" { problem = nil }
    case .failed(let reason, let status):
      responder.wrote(nil, choice: choice)
      log.event(
        "error",
        ["where": "whiteboard_responder", "board": board.id, "responder": new.rawValue, "message": reason])
      var extra: [String: JSONValue] = [
        "board": .string(board.id), "responder": .string(new.rawValue), "ticked": .string(responder.shown.rawValue),
        "cockpit": .string(cockpit),
      ]
      if let status { extra["status"] = .int(status) }
      problem = .grabber(
        "The board couldn't be given to \(new.name): \(reason)", context: "WhiteboardView.responder", extra: extra)
    }
  }
}
