//  Links in a chat thread (#736; spec 2026-10-25-native-chat-design.md, Links in a thread): every pull request, gist
//  and web link a thread's messages hold, as chips — labelled, one per page, newest first.

import Foundation

public struct ChatLink: Equatable, Sendable, Identifiable {
  public enum Kind: Equatable, Sendable {
    case pullRequest(repo: String, number: Int)
    case gist
    case web

    /// The session log's name for it; never the link itself.
    public var logName: String {
      switch self {
      case .pullRequest: return "pr"
      case .gist: return "gist"
      case .web: return "web"
      }
    }
  }

  /// A pull request's state, as the Cockpit tells it (option C, `ChatPRStates`); the raw value is the chip's word.
  public enum PullRequestState: String, Equatable, Sendable { case open, draft, merged, closed }

  /// The link as written, its trailing punctuation dropped.
  public let url: URL
  public let kind: Kind
  /// What the chip reads.
  public let label: String
  /// Two links to the same page share it.
  public let id: String
  /// A PR chip's state once the Cockpit has reported it (`ChatPRStates.applied`); nil reads as the number alone.
  public var state: PullRequestState?

  public init(url: URL, kind: Kind, label: String, id: String, state: PullRequestState? = nil) {
    self.url = url
    self.kind = kind
    self.label = label
    self.id = id
    self.state = state
  }
}

public enum ChatLinks {
  /// The strip's chips before *All links*.
  public static let stripLimit = 10
  /// A wide list row's chips.
  public static let rowLimit = 3
  /// A web chip's path part, before it is cut short.
  static let pathLimit = 24

  /// Every link written out with `http://` or `https://`, in the order written, repeats kept.
  public static func found(in text: String) -> [ChatLink] {
    guard let detector = makeDetector() else { return [] }
    return found(in: text, detector)
  }

  private static func makeDetector() -> NSDataDetector? {
    try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
  }

  private static func found(in text: String, _ detector: NSDataDetector) -> [ChatLink] {
    let ns = text as NSString
    return detector.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
      let written = trimmed(ns.substring(with: match.range))
      let lower = written.lowercased()
      guard lower.hasPrefix("https://") || lower.hasPrefix("http://"), let url = URL(string: written),
        let host = url.host?.lowercased(), !host.isEmpty
      else { return nil }
      return link(url, host: host)
    }
  }

  /// A thread's links, newest message first, one per page (the newest one written).
  public static func inThread(_ messages: [ChatMessage]) -> [ChatLink] {
    guard let detector = makeDetector() else { return [] }
    var seen = Set<String>()
    var out: [ChatLink] = []
    for message in messages.reversed() where !message.isError {
      for link in found(in: message.text, detector) where seen.insert(link.id).inserted {
        out.append(link)
      }
    }
    return out
  }

  /// The strip's chips, and what *All links* adds past them.
  public static func strip(_ links: [ChatLink]) -> (shown: [ChatLink], more: Int) {
    (Array(links.prefix(stripLimit)), max(0, links.count - stripLimit))
  }

  /// Ends a sentence or wraps the link, so it is not part of it: a full stop, quotes, backticks, a bold mark's stars,
  /// a closing bracket with no opening one.
  static func trimmed(_ written: String) -> String {
    var s = Substring(written)
    while let last = s.last {
      if ".,;:!?'\"`*~>".contains(last) {
        s = s.dropLast()
      } else if last == ")" && s.filter({ $0 == "(" }).count < s.filter({ $0 == ")" }).count {
        s = s.dropLast()
      } else if last == "]" && s.filter({ $0 == "[" }).count < s.filter({ $0 == "]" }).count {
        s = s.dropLast()
      } else {
        break
      }
    }
    return String(s)
  }

  private static func link(_ url: URL, host rawHost: String) -> ChatLink {
    let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
    let parts = url.path.split(separator: "/").map(String.init)
    if host == "github.com", parts.count >= 4, parts[2] == "pull", let number = Int(parts[3]) {
      let repo = "\(parts[0])/\(parts[1])".lowercased()
      return ChatLink(
        url: url, kind: .pullRequest(repo: repo, number: number), label: "PR #\(number)", id: "pr:\(repo)#\(number)")
    }
    let page = host + (parts.isEmpty ? "" : "/" + parts.joined(separator: "/")) + (url.query.map { "?" + $0 } ?? "")
    if host == "gist.github.com" { return ChatLink(url: url, kind: .gist, label: "gist", id: page) }
    return ChatLink(url: url, kind: .web, label: webLabel(host: host, parts: parts), id: page)
  }

  /// The site and the last part of the path, with the part before it when the last is only a number.
  private static func webLabel(host: String, parts: [String]) -> String {
    guard let last = parts.last else { return host }
    var path = last
    if parts.count > 1, last.allSatisfy(\.isNumber) { path = parts[parts.count - 2] + "/" + last }
    path = path.removingPercentEncoding ?? path
    if path.count > pathLimit { path = String(path.prefix(pathLimit - 1)) + "…" }
    return host + "/" + path
  }
}
