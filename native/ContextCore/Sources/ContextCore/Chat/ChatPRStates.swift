//  A pull request's state on its chip (#736, option C; spec 2026-10-25-native-chat-design.md, A pull request's state):
//  the refs a thread's PR chips name, the Cockpit's GET /pr-states request and answer, and the chips with their states.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension ChatLink {
  /// The Cockpit's name for a PR chip's pull request, `owner/name#n`; nil for any other chip.
  public var prRef: String? {
    guard case .pullRequest(let repo, let number) = kind else { return nil }
    return "\(repo)#\(number)"
  }

  /// What the chip reads: its label, then its state's word when it has one.
  public var chipText: String { state.map { "\(label) \($0.rawValue)" } ?? label }
}

public enum ChatPRStates {
  /// The most refs one request may name (the Cockpit's limit).
  public static let refLimit = 200
  /// How often PR states are asked for again while chips are on screen.
  public static let pollSeconds = 30.0
  /// How soon after an answer that left a ref pending.
  public static let pendingSeconds = 5.0

  /// The distinct PR refs among these links, in order, at most `refLimit`.
  public static func refs(_ links: [ChatLink]) -> [String] {
    var seen = Set<String>()
    return Array(links.compactMap(\.prRef).filter { seen.insert($0).inserted }.prefix(refLimit))
  }

  /// GET /pr-states?refs=owner/name%23n,... on the chat's Cockpit.
  public static func request(_ refs: [String], cockpit: String) throws -> URLRequest {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~/")
    let names = refs.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0 }
    return try ChatWire.get(cockpit, "/pr-states?refs=" + names.joined(separator: ","))
  }

  /// One answer: each reported ref's state (refs lowercased, as the chips name them), and whether any is still pending.
  public struct Answer: Equatable, Sendable {
    public var states: [String: ChatLink.PullRequestState]
    public var pending: Bool
  }

  /// nil when the body is not an `ok` answer. A state this build doesn't know is left out, so its chip reads as today.
  public static func parse(_ data: Data) -> Answer? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], root["ok"] as? Bool == true
    else { return nil }
    var states: [String: ChatLink.PullRequestState] = [:]
    for (ref, value) in root["states"] as? [String: Any] ?? [:] {
      guard let entry = value as? [String: Any], let state = state(entry) else { continue }
      states[ref.lowercased()] = state
    }
    let pending: Bool
    switch root["pending"] {
    case let list as [Any]: pending = !list.isEmpty
    case let count as Int: pending = count > 0
    default: pending = false
    }
    return Answer(states: states, pending: pending)
  }

  private static func state(_ entry: [String: Any]) -> ChatLink.PullRequestState? {
    switch (entry["state"] as? String)?.uppercased() {
    case "OPEN": return entry["is_draft"] as? Bool == true ? .draft : .open
    case "MERGED": return .merged
    case "CLOSED": return .closed
    default: return nil
    }
  }

  /// The links with their PRs' known states; a PR not in `states` keeps none.
  public static func applied(_ states: [String: ChatLink.PullRequestState], to links: [ChatLink]) -> [ChatLink] {
    links.map { link in
      var out = link
      out.state = link.prRef.flatMap { states[$0] }
      return out
    }
  }
}
