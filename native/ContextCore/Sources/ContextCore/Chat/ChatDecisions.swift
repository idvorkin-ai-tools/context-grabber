//  Decision cards in Chat (#878; spec 2026-11-14-chat-decision-cards-design.md, plan of the same date): Larry's open
//  asks, as the Cockpit's `GET /asks` lists them, and the four ways to finish one — `POST /act` (answer), `/close`
//  (close or abandon) and `/snooze` — with what each answer means. An ask is on a chat when it is that chat's bead:
//  `ask.id == thread.key`, as the Cockpit's own thread page finds it. The model hands in the transport.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
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

  public var marked: Mark? {
    if options.contains(where: { $0.key == defaultKey }) { return Mark(key: defaultKey, word: "Default") }
    if options.contains(where: { $0.key == recommendationKey }) {
      return Mark(key: recommendationKey, word: "Recommended")
    }
    return nil
  }

  enum CodingKeys: String, CodingKey {
    case id, title, context, options, status, expired
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
  }
}

public enum ChatDecisions {
  public typealias Transport = ChatMove.Transport

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
    case snooze(Snooze)
    case close(reason: String)
    case abandon(reason: String?)

    /// The `chat` event's fields: the option's key, the preset, a reason's length — never the words.
    public var logFields: [String: Any] {
      switch self {
      case .answer(let option): return ["option": option.key]
      case .snooze(let preset): return ["action": "snooze", "preset": preset.rawValue]
      case .close(let reason): return ["action": "close", "reason_chars": reason.count]
      case .abandon(let reason): return ["action": "abandon", "reason_chars": reason?.count ?? 0]
      }
    }

    public var word: String {
      switch self {
      case .answer: return "answer"
      case .snooze: return "snooze"
      case .close: return "close"
      case .abandon: return "abandon"
      }
    }
  }

  public enum Outcome: Equatable, Sendable {
    /// The Cockpit took it; a snooze says when it wakes.
    case done(snoozedUntil: String?)
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

  public static func listRequest(cockpit: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    return try ChatWire.get(cockpit, "/asks")
  }

  public static func canClose(reason: String) -> Bool { !reason.trimmingCharacters(in: .whitespaces).isEmpty }

  public static func request(_ verb: Verb, ask: ChatAsk, cockpit: String) throws -> URLRequest {
    let path: String
    let body: [String: String]
    switch verb {
    case .answer(let option):
      // What the Cockpit's own card sends for an option with no note (`submit()` in its index.html).
      path = "/act"
      body = [
        "id": ask.id, "action": "respond", "response": "DECISION: \(option.label)", "base_updated_at": ask.updatedAt,
      ]
    case .snooze(let preset):
      path = "/snooze"
      body = ["id": ask.id, "preset": preset.rawValue]
    case .close(let reason):
      path = "/close"
      body = [
        "id": ask.id, "action": "close", "reason": reason.trimmingCharacters(in: .whitespaces),
        "base_updated_at": ask.updatedAt,
      ]
    case .abandon(let reason):
      path = "/close"
      body = ["id": ask.id, "action": "abandon", "reason": reason ?? "", "base_updated_at": ask.updatedAt]
    }
    guard let base = URL(string: cockpit), base.host != nil, let url = URL(string: cockpit.trimmingSuffix("/") + path)
    else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    // The write boundary answers 415 to a POST that isn't JSON, and refuses one from a foreign origin.
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .refused(error ?? "no answer from the Cockpit") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let said = (json?["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if status == 200, json?["ok"] as? Bool == true {
      return .done(snoozedUntil: json?["snoozed_until"] as? String)
    }
    if status == 409 {
      let fresh = (json?["ask"] as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        .flatMap { try? JSONDecoder().decode(ChatAsk.self, from: $0) }
      if said?.hasPrefix("already closed") == true || fresh?.status == "closed" { return .alreadyAnswered }
      return .changed(fresh)
    }
    return .refused("\(said ?? "the Cockpit refused it") (HTTP \(status))")
  }

  public static func run(_ verb: Verb, ask: ChatAsk, cockpit: String, transport: Transport) async -> Outcome {
    do {
      let (data, status) = try await transport(try request(verb, ask: ask, cockpit: cockpit))
      return outcome(status: status, body: data)
    } catch {
      return outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  // MARK: Which chats carry a card

  /// The chats whose bead is an open ask: their rows say *Decision waiting*.
  public static func waiting(_ threads: [ChatSummary], asks: [ChatAsk]) -> Set<String> {
    let open = Set(asks.map(\.id))
    return Set(threads.map(\.key).filter(open.contains))
  }

  public static func ask(on key: String, in asks: [ChatAsk]) -> ChatAsk? { asks.first { $0.id == key } }

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

  public static let alreadyAnswered = "Already answered elsewhere"
  public static let changed = "This decision changed since it loaded — look again"

  /// The line the card gives way to once the Cockpit has taken it.
  public static func doneLine(_ verb: Verb, snoozedUntil: String?, timeZone: TimeZone = .current) -> String {
    switch verb {
    case .answer(let option): return "You decided: \(option.label)"
    case .close: return "Closed"
    case .abandon: return "Abandoned"
    case .snooze:
      guard let wake = snoozedUntil.flatMap(ChatWire.date) else { return "Snoozed" }
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = timeZone
      f.dateFormat = "EEE h:mm a"
      return "Snoozed until \(f.string(from: wake))"
    }
  }

  public static func problem(_ verb: Verb, _ why: String) -> String { "Could not \(verb.word) this decision: \(why)" }
}
