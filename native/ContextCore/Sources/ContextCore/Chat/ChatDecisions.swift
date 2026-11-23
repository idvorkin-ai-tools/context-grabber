//  Decision cards in Chat (#878; spec 2026-11-14-chat-decision-cards-design.md, plan of the same date): Larry's open
//  asks, as the Cockpit's `GET /asks` lists them, and the four ways to finish one — `POST /act` (answer), `/close`
//  (close or abandon) and `/snooze` — with what each answer means. An ask is on the chat its `thread` names (cockpit-7fr);
//  from a Cockpit that sends no `thread`, on its own bead's chat, `ask.id == thread.key`. The model hands in the
//  transport.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct ChatAsk: Decodable, Equatable, Sendable, Identifiable {
  public struct Option: Decodable, Equatable, Sendable, Identifiable {
    public let key: String
    public let label: String
    public let detail: String
    public var id: String { key }

    public init(key: String, label: String, detail: String = "") {
      self.key = key
      self.label = label
      self.detail = detail
    }
  }

  /// The option the card marks: the ask's default, or else Larry's recommendation.
  public struct Mark: Equatable, Sendable {
    public let key: String
    public let word: String

    public init(key: String, word: String) {
      self.key = key
      self.word = word
    }
  }

  public let id: String
  public let title: String
  public let context: String
  public let options: [Option]
  public let recommendationKey: String
  public let defaultKey: String
  public let status: String
  /// The revision token every verb but snooze sends back: bd has no revision counter.
  public let updatedAt: String
  public let expiresAt: Date?
  public let expired: Bool
  /// The chat the ask continues, as the Cockpit names it: its bd parent's, or its own; nil for none or not sent.
  public let thread: String?
  /// False from a Cockpit older than the `thread` field: the join falls back to the ask's own bead.
  let threadSent: Bool

  /// The chat thread that carries this ask's card, or nil for none.
  public var chat: String? { threadSent ? thread : id }

  /// *Open chat*: the chat it continues, or else its own bead's thread, empty until someone writes there.
  public var chatToOpen: String { chat ?? id }

  public var marked: Mark? {
    if options.contains(where: { $0.key == defaultKey }) { return Mark(key: defaultKey, word: "Default") }
    if options.contains(where: { $0.key == recommendationKey }) {
      return Mark(key: recommendationKey, word: "Recommended")
    }
    return nil
  }

  enum CodingKeys: String, CodingKey {
    case id, title, context, options, status, expired, thread
    case recommendationKey = "recommendation_key"
    case defaultKey = "default"
    case updatedAt = "updated_at"
    case expiresAt = "expires_at"
  }

  struct RawOption: Decodable {
    let key: String?
    let label: String?
    let detail: String?
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = (try? c.decode(String.self, forKey: .title)).flatMap { $0.isEmpty ? nil : $0 } ?? id
    context = (try? c.decode(String.self, forKey: .context)) ?? ""
    let raw = (try? c.decode([RawOption].self, forKey: .options)) ?? []
    // Keyed as normalize_ask keys an option with none.
    options = raw.enumerated().map { i, o in
      Option(
        key: o.key.flatMap { $0.isEmpty ? nil : $0 } ?? "opt\(i + 1)", label: o.label ?? "Option \(i + 1)",
        detail: o.detail ?? "")
    }
    recommendationKey = (try? c.decode(String.self, forKey: .recommendationKey)) ?? ""
    defaultKey = (try? c.decode(String.self, forKey: .defaultKey)) ?? ""
    status = (try? c.decode(String.self, forKey: .status)) ?? ""
    updatedAt = (try? c.decode(String.self, forKey: .updatedAt)) ?? ""
    expiresAt = (try? c.decode(String.self, forKey: .expiresAt)).flatMap(ChatWire.date)
    expired = (try? c.decode(Bool.self, forKey: .expired)) ?? false
    threadSent = c.contains(.thread)
    thread = (try? c.decodeIfPresent(String.self, forKey: .thread)).flatMap { $0?.isEmpty == false ? $0 : nil }
  }
}

public enum ChatDecisions {
  public enum Snooze: String, CaseIterable, Sendable {
    case later, tomorrow
    case nextWeek = "next_week"

    /// The Cockpit card's own words for its three.
    public var label: String {
      switch self {
      case .later: return "Later today"
      case .tomorrow: return "Tomorrow morning"
      case .nextWeek: return "Next week"
      }
    }
  }

  /// The Cockpit's abandon presets; none at all is allowed too.
  public static let abandonReasons = ["Doesn't matter anymore", "Stale", "Already handled", "Not now"]

  public enum Verb: Equatable, Sendable {
    case answer(ChatAsk.Option)
    /// An answer in Igor's own words, as the Inbox's free-text answer (the board's question cards, story 882).
    case ownWords(String)
    case snooze(Snooze)
    case close(reason: String)
    case abandon(reason: String?)

    /// The `chat` event's fields: the option's key, the preset, a reason's length — never the words.
    public var logFields: [String: Any] {
      switch self {
      case .answer(let option): return ["option": option.key]
      case .ownWords(let words): return ["option": "own", "answer_chars": words.count]
      case .snooze(let preset): return ["action": "snooze", "preset": preset.rawValue]
      case .close(let reason): return ["action": "close", "reason_chars": reason.count]
      case .abandon(let reason): return ["action": "abandon", "reason_chars": reason?.count ?? 0]
      }
    }

    public var word: String {
      switch self {
      case .answer, .ownWords: return "answer"
      case .snooze: return "snooze"
      case .close: return "close"
      case .abandon: return "abandon"
      }
    }
  }

  /// The Cockpit's `chat` on a 200 to `post_to_chat`: whether Igor's row went into the ask's thread, and why not.
  public struct Posted: Equatable, Sendable {
    public let posted: Bool
    public let thread: String?
    public let error: String?

    public init(posted: Bool, thread: String?, error: String?) {
      self.posted = posted
      self.thread = thread
      self.error = error
    }
  }

  public enum Outcome: Equatable, Sendable {
    /// The Cockpit took it; a snooze says when it wakes; `chat` is nil when the Cockpit said nothing about the chat.
    case done(snoozedUntil: String?, chat: Posted? = nil)
    /// The ask changed since it was read: as it now is, or nil when the answer didn't say (read the asks again).
    case changed(ChatAsk?)
    /// Answered, closed or abandoned elsewhere first.
    case alreadyAnswered
    /// Why not, for the copyable problem; the card stays.
    case refused(String)

    public var logName: String {
      switch self {
      case .done: return "ok"
      case .changed: return "changed"
      case .alreadyAnswered: return "already_answered"
      case .refused: return "refused"
      }
    }
  }

  struct List: Decodable {
    let ok: Bool
    let asks: [ChatAsk]
  }

  /// The open asks in the Cockpit's queue order, or nil for an answer that is not that list.
  public static func asks(_ data: Data) -> [ChatAsk]? {
    guard let list = try? JSONDecoder().decode(List.self, from: data), list.ok else { return nil }
    return list.asks
  }

  public static func canClose(reason: String) -> Bool { !reason.trimmingCharacters(in: .whitespaces).isEmpty }

  /// Igor's own words answer only once there are some.
  public static func canSend(words: String) -> Bool { !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  /// Why a verb may not go: an own-answer option's bare label, or an own answer with no words (Igor, 2026-11-22).
  public enum NotSent: Error, Equatable, LocalizedError {
    case ownAnswerLabel
    case noWords

    public var errorDescription: String? {
      switch self {
      case .ownAnswerLabel: return "an own-answer option goes only with Igor's words, never its label"
      case .noWords: return "an own answer needs words"
      }
    }
  }

  /// Igor's row in the ask's chat once the decision lands (cockpit-7fr): only the literal true turns it on, and
  /// `source` names the phone as on `/chat`. A snooze has none.
  package static let postToChat: [String: Any] = ["post_to_chat": true, "source": "app"]

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .refused(error ?? "no answer from the Cockpit") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let said = (json?["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if status == 200, json?["ok"] as? Bool == true {
      let chat = (json?["chat"] as? [String: Any]).map {
        Posted(
          posted: $0["posted"] as? Bool == true, thread: $0["thread"] as? String, error: $0["error"] as? String)
      }
      return .done(snoozedUntil: json?["snoozed_until"] as? String, chat: chat)
    }
    if status == 409 {
      let fresh = (json?["ask"] as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        .flatMap { try? JSONDecoder().decode(ChatAsk.self, from: $0) }
      if said?.hasPrefix("already closed") == true || fresh?.status == "closed" { return .alreadyAnswered }
      return .changed(fresh)
    }
    return .refused("\(said ?? "the Cockpit refused it") (HTTP \(status))")
  }

  // MARK: Which chats carry a card

  /// The chats an open ask continues: their rows say *Decision waiting*.
  public static func waiting(_ threads: [ChatSummary], asks: [ChatAsk]) -> Set<String> {
    let open = Set(asks.compactMap(\.chat))
    return Set(threads.map(\.key).filter(open.contains))
  }

  /// The card at the top of a thread: the first, in the Cockpit's order, of the asks that continue it.
  public static func ask(on key: String, in asks: [ChatAsk]) -> ChatAsk? { asks.first { $0.chat == key } }

  // MARK: Igor's row in the chat

  /// In a thread, a card the Cockpit wrote into the chat gives way to that message, not to a line.
  public static func givesWayToMessage(_ verb: Verb, chat: Posted?, inThread: Bool) -> Bool {
    if case .snooze = verb { return false }
    return inThread && chat?.posted == true
  }

  /// The `chat` event's word on the chat row: none for a snooze, which asks for none.
  public static func chatLogFields(_ verb: Verb, chat: Posted?) -> [String: Any] {
    if case .snooze = verb { return [:] }
    guard let chat else { return ["chat_posted": false, "chat_error": "no chat field"] }
    if chat.posted { return ["chat_posted": true] }
    return ["chat_posted": false, "chat_error": chat.error ?? "no reason given"]
  }

  /// The row *Decisions (N)* follows: Larry's pinned thread, or nil to lead the list.
  public static func rowAfter(_ live: [ChatSummary]) -> String? {
    live.first { $0.pinned && $0.skill == nil }?.key
  }

  // MARK: The card's lines

  public struct Expiry: Equatable, Sendable {
    public let text: String
    public let expired: Bool

    public init(text: String, expired: Bool) {
      self.text = text
      self.expired = expired
    }
  }

  public static func expiry(_ at: Date?, now: Date) -> Expiry? {
    guard let at else { return nil }
    let left = at.timeIntervalSince(now)
    let span = span(abs(left))
    if left > 0 { return Expiry(text: span.map { "Expires in \($0)" } ?? "Expires in under a minute", expired: false) }
    return Expiry(text: span.map { "Expired \($0) ago" } ?? "Expired just now", expired: true)
  }

  /// Whole units, rounded down: minutes under an hour, hours under two days, then days. Nil under a minute.
  private static func span(_ seconds: TimeInterval) -> String? {
    let minutes = Int(seconds / 60)
    if minutes < 1 { return nil }
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    return hours < 48 ? "\(hours) h" : "\(hours / 24) d"
  }

  /// Story 1603 (bead context-grabber-o2i2): how tall the part of a card under its heading may grow at the top of its
  /// thread, which stays put while the chat scrolls under it, so the card with its heading comes to about 60% of the
  /// thread. Never under a few lines' worth. Nil until the thread has been measured: the card is drawn unbounded.
  public static func threadCardBodyCap(threadHeight: Double) -> Double? {
    guard threadHeight > 0 else { return nil }
    return max(threadCardBodyFloor, threadHeight * 0.5)
  }

  public static let threadCardBodyFloor = 120.0

  public static let alreadyAnswered = "Already answered elsewhere"
  public static let changed = "This decision changed since it loaded — look again"

  /// The line the card gives way to once the Cockpit has taken it.
  public static func doneLine(_ verb: Verb, snoozedUntil: String?, timeZone: TimeZone = .current) -> String {
    switch verb {
    case .answer(let option): return "You decided: \(option.label)"
    case .ownWords(let words): return "You decided: \(words.trimmingCharacters(in: .whitespacesAndNewlines))"
    case .close: return "Closed"
    case .abandon: return "Abandoned"
    case .snooze:
      guard let wake = snoozedUntil.flatMap(ChatWire.date) else { return "Snoozed" }
      #if FOUNDATION_ESSENTIALS_ONLY
        // The wasm has no DateFormatter, and no board shows this line.
        return "Snoozed until \(LiteText.weekdayTime(wake, timeZone: timeZone))"
      #else
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "EEE h:mm a"
        return "Snoozed until \(f.string(from: wake))"
      #endif
    }
  }

  public static func problem(_ verb: Verb, _ why: String) -> String { "Could not \(verb.word) this decision: \(why)" }

  // MARK: Other: an answer in Igor's own words (story 1128, bead context-grabber-sm4l)

  /// The labels that mean "my own answer", lowercased, with no punctuation around them.
  static let ownAnswerLabels: Set<String> = [
    "other", "something else", "type your own answer", "your own answer", "none of these", "none of the above",
  ]

  /// Larry's own-answer option: keyed `other` (whatever its label), or labelled *Other*, *Something else*, *Type your
  /// own answer*, *Your own answer*, *None of these* or *None of the above*, in any case and with any punctuation around
  /// it, alone or as one half of a label such as *Something else / Type your own answer* (Igor, 2026-11-22: that one went as *DECISION: Something else*).
  public static func isOther(_ option: ChatAsk.Option) -> Bool {
    if option.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "other" { return true }
    let halves = option.label.lowercased().components(separatedBy: CharacterSet(charactersIn: "/|()—"))
      .flatMap { $0.components(separatedBy: " - ") }
    return halves.contains { half in
      let words = half.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
      return ownAnswerLabels.contains(words.joined(separator: " "))
    }
  }

  /// Whether the card adds its own *Other…*: not when Larry's options already have one, which is the way in instead.
  /// The board's popup adds none either way: its own *Your own answer* field is always under the card.
  public static func addsOther(_ ask: ChatAsk) -> Bool { !ask.options.contains(where: isOther) }

  /// What a tap on an option does: answer with it, or, for Larry's *Other*, open the own-words field. The bare word
  /// *Other* is never an answer.
  public enum Tap: Equatable, Sendable {
    case answer(Verb)
    case openOther
  }

  public static func tap(_ option: ChatAsk.Option) -> Tap { isOther(option) ? .openOther : .answer(.answer(option)) }

  /// The `decision_shown` event's word on *Other*: the ask's own (drawn everywhere, the board's popup too), the card's
  /// added *Other…*, or none (the board's popup, whose own field is under the card).
  public static func otherLogName(_ ask: ChatAsk, addsOwn: Bool) -> String {
    if !addsOther(ask) { return "ask" }
    return addsOwn ? "added" : "none"
  }
}
