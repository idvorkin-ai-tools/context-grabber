//  Send to new chat (context-grabber-9yo; chat spec, Press and hold a message): one of Igor's messages leaves its chat
//  for a brand-new one. `POST /chat/move` {"thread", "message_id"} answers 200 {"thread", "title"}: the new chat and its
//  first line. 404 is an unknown chat or message; 409 a message that isn't Igor's or was already moved; a Cockpit from
//  before the route answers 400. The old chat keeps a system row naming the new one (`ChatMessage.movedTo`). The chat's
//  model hands in the transport, so a host test can answer it.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum ChatMove {
  /// `POST` the request; the answer's body and HTTP status (nil when it wasn't HTTP).
  public typealias Transport = @MainActor (URLRequest) async throws -> (Data, Int?)

  public enum Outcome: Equatable, Sendable {
    /// The new chat's key and title.
    case moved(thread: String, title: String)
    /// Why not, for the copyable problem; the message stays where it was.
    case refused(String)
  }

  /// The title a new chat shows until the Cockpit's list names it, when the answer gave none.
  public static let untitled = "New chat"

  public static func request(thread: String, message: String, cockpit: String) throws -> URLRequest {
    guard let url = URL(string: cockpit.trimmingSuffix("/") + "/chat/move"), let base = URL(string: cockpit) else {
      throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    // The Cockpit's write boundary answers 415 to a POST that isn't JSON, and refuses one from a foreign origin.
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["thread": thread, "message_id": message])
    return request
  }

  /// What the Cockpit's answer means. Anything but a 200 naming a new chat is a refusal: an older Cockpit may answer a
  /// route it lacks with something other than 404.
  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .refused(error ?? "no answer from the Cockpit") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let said = (json?["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if status == 200, json?["ok"] as? Bool != false, let thread = json?["thread"] as? String, !thread.isEmpty {
      let title = (json?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? untitled
      return .moved(thread: thread, title: title)
    }
    let why: String
    switch status {
    case 200: why = said ?? "the Cockpit's answer named no new chat"
    // Today's Cockpit reads /chat/move as a message for a chat called "move" and answers 400 "chat message needs
    // text": its words alone would say nothing to Igor.
    case 400: why = "the Cockpit can't move messages yet, or refused this one" + (said.map { ": \($0)" } ?? "")
    case 404: why = said ?? "the Cockpit has no such message here, or can't move messages yet"
    case 409: why = said ?? "it was already moved, or it isn't yours"
    default: why = said ?? "the Cockpit refused it"
    }
    return .refused("\(why) (HTTP \(status))")
  }

  /// One move, start to answer.
  public static func run(thread: String, message: String, cockpit: String, transport: Transport) async -> Outcome {
    do {
      let (data, status) = try await transport(try request(thread: thread, message: message, cockpit: cockpit))
      return outcome(status: status, body: data)
    } catch {
      return outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  /// The Cockpit's own line in a thread (`ChatMessage.isSystem`), as it reads: its words, and the chat a tap opens when
  /// it names one. Nil for an ordinary message.
  public struct Line: Equatable, Sendable {
    public let words: String
    public let opens: String?
  }

  /// What the old chat's moved line says when the Cockpit sent no words.
  public static let movedWords = "Moved to a new chat"

  public static func line(_ message: ChatMessage) -> Line? {
    guard message.isSystem else { return nil }
    let words = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return Line(words: words.isEmpty ? movedWords : words, opens: message.movedTo)
  }

  /// The problem's words at the top of the thread.
  public static func problem(_ why: String) -> String { "Could not send this to a new chat: \(why)" }
}
