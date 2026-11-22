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
    "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid", "igshid", "igsh",
    "mc_cid", "mc_eid", "mkt_tok", "_hsenc", "_hsmi",
  ]

  /// Where `si` marks who shared the link; anywhere else it may be part of the page's address.
  static let shareTagSites: Set<String> = ["youtube.com", "music.youtube.com", "youtu.be", "open.spotify.com"]

  private static func isTracking(_ name: String, site: String) -> Bool {
    let name = name.lowercased()
    return tracking.contains(name) || name.hasPrefix("utm_") || (name == "si" && shareTagSites.contains(site))
  }

  /// What two addresses of the same page share: the site without `www.`, the path without a trailing slash and the
  /// query without tracking tags, in name order. A fragment is kept only when it is a route (`#/…`, `#!…`), which on
  /// some sites is the page. Nil for anything but a web link.
  public static func key(_ url: String) -> String? {
    guard let parts = URLComponents(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
      var host = parts.host?.lowercased(), !host.isEmpty
    else { return nil }
    if host.hasPrefix("www.") { host.removeFirst(4) }
    let site = host
    if let port = parts.port, port != (scheme == "http" ? 80 : 443) { host += ":\(port)" }
    var path = parts.percentEncodedPath
    while path.hasSuffix("/") { path.removeLast() }
    let query = (parts.percentEncodedQueryItems ?? [])
      .filter { !isTracking($0.name, site: site) }
      .map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }
      .sorted()
    let route = parts.percentEncodedFragment.flatMap { $0.hasPrefix("/") || $0.hasPrefix("!") ? "#" + $0 : nil }
    return host + path + (query.isEmpty ? "" : "?" + query.joined(separator: "&")) + (route ?? "")
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

  /// The chats shared links started within the window before `now`. A ledger that is missing or unreadable is no
  /// starts: the card then recommends nothing, which is how it looked before.
  public func linkStarts(now: Date = Date()) -> [ShareSameLink.Start] {
    ShareSameLink.kept(allLinkStarts(), now: Int64(now.timeIntervalSince1970 * 1000))
  }

  private func allLinkStarts() -> [ShareSameLink.Start] {
    (try? Data(contentsOf: linkStartsFile)).flatMap { try? JSONDecoder().decode([ShareSameLink.Start].self, from: $0) }
      ?? []
  }

  /// Drops the starts the window has left behind, and the ledger with the last of them. The app's to call, as the
  /// one writer: the share card only reads. Returns how many it dropped.
  @discardableResult
  public func forgetOldLinkStarts(now: Date = Date()) throws -> Int {
    let all = allLinkStarts()
    let kept = ShareSameLink.kept(all, now: Int64(now.timeIntervalSince1970 * 1000))
    guard kept.count < all.count else { return 0 }
    try writeLinkStarts(kept)
    return all.count - kept.count
  }

  private func writeLinkStarts(_ starts: [ShareSameLink.Start]) throws {
    guard !starts.isEmpty else { return try FileManager.default.removeItem(at: linkStartsFile) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(starts).write(to: linkStartsFile, options: .atomic)
  }

  /// Remembers that `url` started `thread` at `at` (Unix ms), and forgets what is older than the window. False when
  /// `url` is not a web link, so nothing was kept.
  @discardableResult
  public func recordLinkStart(url: String, thread: String, at: Int64) throws -> Bool {
    guard let link = ShareSameLink.key(url) else { return false }
    var starts = allLinkStarts().filter { !($0.link == link && $0.thread == thread) }
    starts.append(ShareSameLink.Start(link: link, thread: thread, startedAt: at))
    try writeLinkStarts(ShareSameLink.kept(starts, now: at))
    return true
  }
}
