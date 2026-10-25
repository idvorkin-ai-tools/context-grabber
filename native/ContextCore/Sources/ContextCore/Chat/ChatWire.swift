//  Chat with Larry: what the Cockpit's chat routes answer, as the app reads them (plan 2026-10-25-native-chat-plan.md).
//  `GET /chat` lists every thread with a server-side unread count and the Done fold; `GET /chat/<key>` is one thread's
//  messages, Igor's carrying 👀/🏆 receipts; `POST /chat-seen` marks a thread read on every device.

import Foundation

public struct ChatSummary: Decodable, Equatable, Sendable, Identifiable {
  public let key: String
  public let title: String
  public let count: Int
  /// ISO 8601 with an offset, as the Cockpit writes it.
  public let lastTs: String
  public let lastWho: String
  public let lastText: String
  public let unread: Int
  public let done: Bool

  public var id: String { key }
  public var larryHasLastWord: Bool { lastWho == "larry" }
  public var lastAt: Date? { ChatWire.date(lastTs) }

  public init(
    key: String, title: String, count: Int = 1, lastTs: String, lastWho: String, lastText: String, unread: Int = 0,
    done: Bool = false
  ) {
    self.key = key
    self.title = title
    self.count = count
    self.lastTs = lastTs
    self.lastWho = lastWho
    self.lastText = lastText
    self.unread = unread
    self.done = done
  }

  enum CodingKeys: String, CodingKey {
    case key, title, count, unread, done
    case lastTs = "last_ts"
    case lastWho = "last_who"
    case lastText = "last_text"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    title = (try? c.decode(String.self, forKey: .title)) ?? key
    count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    lastTs = (try? c.decode(String.self, forKey: .lastTs)) ?? ""
    lastWho = (try? c.decode(String.self, forKey: .lastWho)) ?? ""
    lastText = (try? c.decode(String.self, forKey: .lastText)) ?? ""
    unread = (try? c.decode(Int.self, forKey: .unread)) ?? 0
    done = (try? c.decode(Bool.self, forKey: .done)) ?? false
  }
}

public struct ChatMessage: Decodable, Equatable, Sendable, Identifiable {
  public enum Receipt: String, Sendable { case sent, seen, done }

  public let id: String
  public let ts: String
  public let who: String
  public let text: String
  public let attachments: [String]
  public let receipt: Receipt
  /// Larry's note when he marked it done.
  public let doneNote: String?

  public var fromIgor: Bool { who == "igor" }
  public var at: Date? { ChatWire.date(ts) }

  public init(
    id: String, ts: String, who: String, text: String, attachments: [String] = [], receipt: Receipt = .sent,
    doneNote: String? = nil
  ) {
    self.id = id
    self.ts = ts
    self.who = who
    self.text = text
    self.attachments = attachments
    self.receipt = receipt
    self.doneNote = doneNote
  }

  enum CodingKeys: String, CodingKey { case id, ts, who, text, attachments, receipt }
  struct ReceiptBody: Decodable {
    let state: String?
    let note: String?
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    ts = (try? c.decode(String.self, forKey: .ts)) ?? ""
    who = (try? c.decode(String.self, forKey: .who)) ?? ""
    text = (try? c.decode(String.self, forKey: .text)) ?? ""
    attachments = (try? c.decode([String].self, forKey: .attachments)) ?? []
    let body = try? c.decode(ReceiptBody.self, forKey: .receipt)
    receipt = body?.state.flatMap(Receipt.init(rawValue:)) ?? .sent
    doneNote = body?.note
  }
}

public enum ChatWire {
  struct List: Decodable {
    let ok: Bool
    let threads: [ChatSummary]
  }

  struct Thread: Decodable {
    let ok: Bool
    let messages: [ChatMessage]
  }

  /// Every thread, newest activity first, or nil for an answer that is not a chat list.
  public static func summaries(_ data: Data) -> [ChatSummary]? {
    guard let list = try? JSONDecoder().decode(List.self, from: data), list.ok else { return nil }
    return list.threads.sorted { ($0.lastAt ?? .distantPast) > ($1.lastAt ?? .distantPast) }
  }

  public static func messages(_ data: Data) -> [ChatMessage]? {
    guard let thread = try? JSONDecoder().decode(Thread.self, from: data), thread.ok else { return nil }
    return thread.messages
  }

  public static func listRequest(cockpit: String) throws -> URLRequest {
    try get(cockpit, "/chat")
  }

  public static func threadRequest(_ key: String, cockpit: String) throws -> URLRequest {
    try get(cockpit, "/chat/" + encode(key))
  }

  public static func seenRequest(_ key: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("chat-seen"))
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["thread": key])
    return request
  }

  /// Where an attachment's image is served; nil for a ref that is not one the Cockpit mints.
  public static func attachmentURL(_ ref: String, cockpit: String) -> URL? {
    guard ref.range(of: #"^\d{4}-\d{2}-\d{2}/[0-9a-f]{16}\.(png|jpg|gif|webp)$"#, options: .regularExpression) != nil
    else { return nil }
    return URL(string: cockpit.trimmingSuffix("/") + "/attachments/" + ref)
  }

  /// A thread key as one path segment: `auto:note:2026-10-25` and bead ids survive, a slash cannot sneak in.
  public static func encode(_ key: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~:")
    return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
  }

  public static func date(_ iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    if let d = f.date(from: iso) { return d }
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: iso)
  }

  static func get(_ cockpit: String, _ path: String) throws -> URLRequest {
    guard let url = URL(string: cockpit.trimmingSuffix("/") + path) else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }
}

/// Which threads get a notification (plan: Hearing back). Larry has the last word, the Cockpit counts it unread, and
/// it is newer than what this phone last notified — or showed on screen — for that thread.
public enum ChatNotify {
  public static func due(_ summaries: [ChatSummary], notified: [String: String]) -> [ChatSummary] {
    summaries.filter { summary in
      guard summary.larryHasLastWord, summary.unread > 0, let last = summary.lastAt else { return false }
      guard let before = notified[summary.key].flatMap(ChatWire.date) else { return true }
      return last > before
    }
  }

  /// Every thread's latest stamp, merged over what was recorded: what the app has now shown or notified.
  public static func record(_ summaries: [ChatSummary], into notified: [String: String]) -> [String: String] {
    var out = notified
    for summary in summaries where !summary.lastTs.isEmpty { out[summary.key] = summary.lastTs }
    return out
  }
}
