//  #794, stories 559 and 740–742 (chat spec, The chat this link already started): the share card recommends the chat
//  a link started in the last eight hours. The phone drops a message once its thread shows it, so which chat each
//  shared link started is kept apart, beside the Inbox in the App Group: the app writes it, the extension reads it.

import Foundation

public enum ShareSameLink {
  /// How long after a link started a chat the card still recommends that chat (the spec says why eight hours).
  public static let window: TimeInterval = 8 * 3600

  /// A chat a shared link started.
  public struct Start: Codable, Equatable, Sendable {
    /// The link's `key`, not the address as shared.
    public let link: String
    public let thread: String
    /// Unix ms when the Cockpit took the share.
    public let startedAt: Int64

    public init(link: String, thread: String, startedAt: Int64) {
      self.link = link
      self.thread = thread
      self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
      case link, thread
      case startedAt = "started_at"
    }
  }

  /// Query names that only say where a click came from; `utm_…` is matched by its prefix.
  static let tracking: Set<String> = [
    "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid", "igshid", "igsh", "si",
    "mc_cid", "mc_eid", "mkt_tok", "_hsenc", "_hsmi",
  ]

  /// What two addresses of the same page share: the site without `www.`, the path without a trailing slash and the
  /// query without tracking tags, in name order. Nil for anything but a web link.
  public static func key(_ url: String) -> String? {
    guard let parts = URLComponents(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
      var host = parts.host?.lowercased(), !host.isEmpty
    else { return nil }
    if host.hasPrefix("www.") { host.removeFirst(4) }
    if let port = parts.port, port != (scheme == "http" ? 80 : 443) { host += ":\(port)" }
    var path = parts.percentEncodedPath
    while path.hasSuffix("/") { path.removeLast() }
    let query = (parts.percentEncodedQueryItems ?? [])
      .filter { !tracking.contains($0.name.lowercased()) && !$0.name.lowercased().hasPrefix("utm_") }
      .map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }
      .sorted()
    return host + path + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))
  }

  /// The chat to recommend for `url`: the most recently started one this link started within the window that the
  /// Cockpit still lists as live. Nil when there is none.
  public static func recommended(url: String?, starts: [Start], live: [ChatSummary], now: Date) -> String? {
    guard let link = url.flatMap(key) else { return nil }
    let liveKeys = Set(live.map(\.key))
    return kept(starts, now: Int64(now.timeIntervalSince1970 * 1000))
      .filter { $0.link == link && liveKeys.contains($0.thread) }
      .max { $0.startedAt < $1.startedAt }?
      .thread
  }

  /// The starts the window still holds.
  static func kept(_ starts: [Start], now: Int64) -> [Start] {
    starts.filter { $0.startedAt >= now - Int64(window * 1000) }
  }
}

extension InboxStore {
  /// Not `.json`: the Inbox reads every `.json` here as an item.
  private var linkStartsFile: URL { directory.appendingPathComponent("link-starts.ledger") }

  /// The chats shared links started, as last written. A ledger that is missing or unreadable is no starts: the card
  /// then recommends nothing, which is how it looked before.
  public func linkStarts() -> [ShareSameLink.Start] {
    (try? Data(contentsOf: linkStartsFile)).flatMap { try? JSONDecoder().decode([ShareSameLink.Start].self, from: $0) }
      ?? []
  }

  /// Remembers that `url` started `thread` at `at` (Unix ms), and forgets what is older than the window. False when
  /// `url` is not a web link, so nothing was kept.
  @discardableResult
  public func recordLinkStart(url: String, thread: String, at: Int64) throws -> Bool {
    guard let link = ShareSameLink.key(url) else { return false }
    var starts = linkStarts().filter { !($0.link == link && $0.thread == thread) }
    starts.append(ShareSameLink.Start(link: link, thread: thread, startedAt: at))
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(ShareSameLink.kept(starts, now: at)).write(to: linkStartsFile, options: .atomic)
    return true
  }
}
