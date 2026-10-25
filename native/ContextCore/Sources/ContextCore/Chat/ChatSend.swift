//  Chat with Larry (spec 2026-10-25-native-chat-design.md, plan 2026-10-25-native-chat-plan.md): an Inbox item goes
//  out as a chat message on the Cockpit's threads. An image is uploaded first (`POST /attachments`, raw bytes) and
//  named by the ref it gets back; then the message: `POST /chat` starts a new thread, `POST /chat/<key>` adds to one.
//  The item's id is the message id, so a resend after a lost answer lands once (cockpit#64, Cockpit story 129).

import Foundation

public enum ChatSend {
  /// What Cockpit's chat calls a message from this app.
  public static let source = "app"
  /// The longest title a new thread gets from its first message.
  public static let maxTitle = 80

  public enum Upload: Equatable, Sendable {
    case ref(String)
    case refused(status: Int, reason: String)
    case retry(reason: String)
  }

  public enum Outcome: Equatable, Sendable {
    /// Taken (or taken before: `duplicate`), on this thread.
    case sent(thread: String, duplicate: Bool)
    case refused(status: Int, reason: String)
    case retry(reason: String)
  }

  /// What the message says: a link is its address then the note, text is the text then the note, an image its note.
  public static func text(for item: InboxItem) -> String {
    let parts: [String?]
    switch item.kind {
    case .link: parts = [item.url, item.note]
    case .text: parts = [item.text, item.note]
    case .image: parts = [item.note]
    }
    return parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  /// A new thread's title: the note's first line, else the text's, else the link's site, else *Photo, <date>*.
  public static func title(for item: InboxItem, timeZone: TimeZone = .current) -> String {
    let firstLine = { (s: String?) -> String? in
      s?.split(whereSeparator: \.isNewline).lazy.map { $0.trimmingCharacters(in: .whitespaces) }
        .first { !$0.isEmpty }
    }
    let picked =
      firstLine(item.note) ?? (item.kind == .text ? firstLine(item.text) : nil) ?? item.site
      ?? (item.kind == .image ? "Photo, \(day(item.sharedAt, timeZone))" : nil) ?? firstLine(item.url) ?? "Chat"
    guard picked.count > maxTitle else { return picked }
    return String(picked.prefix(maxTitle - 1)).trimmingCharacters(in: .whitespaces) + "…"
  }

  public static func uploadRequest(image: Data, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("attachments"))
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue(InboxSend.mime(of: image), forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = image
    return request
  }

  public static func upload(status: Int?, body: Data?, error: String? = nil) -> Upload {
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard let status else { return .retry(reason: error ?? "no answer") }
    if status == 200, json?["ok"] as? Bool == true, let ref = json?["ref"] as? String, !ref.isEmpty {
      return .ref(ref)
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }

  /// The message itself; `attachment` is the ref an upload returned.
  public static func messageRequest(_ item: InboxItem, attachment: String?, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var body: [String: Any] = ["id": item.id, "text": text(for: item), "source": source]
    if let attachment { body["attachments"] = [attachment] }
    let url: URL?
    if let thread = item.thread {
      url = URL(string: base.absoluteString.trimmingSuffix("/") + "/chat/" + ChatWire.encode(thread))
    } else {
      body["title"] = title(for: item)
      url = base.appendingPathComponent("chat")
    }
    guard let url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard let status else { return .retry(reason: error ?? "no answer") }
    if status == 200, json?["ok"] as? Bool == true, let thread = json?["thread"] as? String, !thread.isEmpty {
      return .sent(thread: thread, duplicate: json?["duplicate"] as? Bool == true)
    }
    let reason = (json?["error"] as? String) ?? (json?["reason"] as? String) ?? "HTTP \(status)"
    // 404 is a thread the Cockpit no longer has: wrong for good, like any other 4xx.
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }

  static func day(_ ms: Int64, _ timeZone: TimeZone) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "MMM d"
    return f.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
  }
}

extension String {
  func trimmingSuffix(_ suffix: String) -> String { hasSuffix(suffix) ? String(dropLast(suffix.count)) : self }
}
