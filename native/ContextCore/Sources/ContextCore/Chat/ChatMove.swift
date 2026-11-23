//  Send to new chat (context-grabber-9yo; chat spec, Press and hold a message): one of Igor's messages leaves its chat
//  for a brand-new one. `POST /chat/move` {"thread", "message_id"} answers 200 {"thread", "title"}: the new chat and its
//  first line. 404 is an unknown chat or message; 409 a message that isn't Igor's or was already moved; a Cockpit from
//  before the route answers 400. The old chat keeps a system row naming the new one (`ChatMessage.movedTo`). The chat's
//  model hands in the transport, so a host test can answer it.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum ChatMove {
  public enum Outcome: Equatable, Sendable {
    /// The new chat's key and title.
    case moved(thread: String, title: String)
    /// Why not, for the copyable problem; the message stays where it was.
    case refused(String)
  }

  /// The title a new chat shows until the Cockpit's list names it, when the answer gave none.
  public static let untitled = "New chat"

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

  /// The Cockpit's own line in a thread (`ChatMessage.isSystem`), as it reads: its words, and the chat a tap opens when
  /// it names one. Nil for an ordinary message.
  public struct Line: Equatable, Sendable {
    public let words: String
    public let opens: String?

    public init(words: String, opens: String?) {
      self.words = words
      self.opens = opens
    }
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
