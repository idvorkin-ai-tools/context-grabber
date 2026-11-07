//  Press and hold a message in Chat (#629, chat spec "Press and hold a message", stories 518-519, 540-542): what Yes,
//  No and Quote in reply write. The Cockpit has no reactions, so a reaction is an ordinary message and a quote is its text.

import Foundation

public enum ChatReaction: String, CaseIterable, Sendable {
  case yes, no

  public var label: String { self == .yes ? "Yes" : "No" }

  /// The message a reaction sends. A bare word answers whatever was said last, so one on an older message goes under a
  /// quote of what it answers.
  public func text(answering message: ChatMessage, newest: Bool) -> String {
    newest ? label : ChatQuote.quoted(message) + "\n\n" + label
  }
}

/// What holding a message offers (stories 518, 540-541): Yes and No answer Larry, so never on Igor's own message, and
/// Quote in reply and Copy take its words, so never on a picture alone. Only Yes and No send anything.
public enum ChatHold: Hashable, Sendable {
  case react(ChatReaction), quote, copy

  /// The hold menu for `message`, in its order.
  public static func choices(for message: ChatMessage) -> [ChatHold] {
    let answers = message.fromIgor ? [] : ChatReaction.allCases.map(ChatHold.react)
    let hasWords = !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    return answers + (hasWords ? [.quote, .copy] : [])
  }

  /// GRABBER_CHAT_HOLD's value (yes, no, quote or copy): the choice that taps itself on the simulator.
  public init?(hook: String) {
    switch hook {
    case "quote": self = .quote
    case "copy": self = .copy
    default:
      guard let reaction = ChatReaction(rawValue: hook) else { return nil }
      self = .react(reaction)
    }
  }

  public var label: String {
    switch self {
    case .react(let reaction): reaction.label
    case .quote: "Quote in reply"
    case .copy: "Copy"
    }
  }

  public var systemImage: String {
    switch self {
    case .react(let reaction): reaction == .yes ? "hand.thumbsup" : "hand.thumbsdown"
    case .quote: "text.quote"
    case .copy: "doc.on.doc"
    }
  }
}

public enum ChatQuote {
  /// The most of a message a quote carries: a long reply would otherwise fill the bar and bury the answer.
  public static let maxCharacters = 280
  /// What stands in for a message that is only a picture.
  public static let picture = "A picture"

  /// Its words with each line marked `> `; a blank line is a bare `>`, so the quote holds together.
  public static func quoted(_ message: ChatMessage) -> String {
    let words = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let kept =
      words.count > maxCharacters
      ? String(words.prefix(maxCharacters - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
      : words.isEmpty ? picture : words
    return kept.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .map { $0.isEmpty ? ">" : "> " + $0 }
      .joined(separator: "\n")
  }

  /// The bar after a quote: what it held, then the quote, then the blank line the reply starts on.
  public static func appended(_ message: ChatMessage, to draft: String) -> String {
    let held = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    return (held.isEmpty ? "" : held + "\n\n") + quoted(message) + "\n\n"
  }
}
