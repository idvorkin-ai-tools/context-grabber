//  Site names come from the Cockpit (story 1135; spec 2026-10-25-native-chat-design.md, Links in a thread): a web
//  chip reads a site's short name in place of the site, from the list the Cockpit gives, so a new name needs no app
//  release. The app's own names stand until it has a list.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct ChatSiteNames: Equatable, Sendable {
  /// Each site (lower-case, no *www.*) and the name its chips read.
  public let names: [String: String]

  public init(names: [String: String]) {
    var out: [String: String] = [:]
    for (site, name) in names {
      let name = name.trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty else { continue }
      out[Self.site(site)] = name
    }
    self.names = out
  }

  /// The names the app ships with: the Cockpit's list as it was when this build was made.
  public static let shipped = ChatSiteNames(names: ["idvorkin-ai-tools.github.io": "ai-tools"])

  /// The Cockpit's path for its list: `{"sites": {"<site>": "<name>", ...}}`.
  public static let path = "/link-labels"

  /// The list a chip reads now: the shipped one until the app has the Cockpit's.
  public static var current: ChatSiteNames {
    get {
      lock.lock()
      defer { lock.unlock() }
      return stored
    }
    set {
      lock.lock()
      stored = newValue
      lock.unlock()
    }
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var stored = shipped

  /// The name for a site (with or without *www.*), or nil when the list has none.
  public func name(for host: String) -> String? { names[Self.site(host)] }

  /// The Cockpit's answer, or the app's saved copy; nil when it isn't a list of names, so nothing changes.
  public static func parse(_ data: Data) -> ChatSiteNames? {
    guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
    return ChatSiteNames(names: wire.sites)
  }

  /// What the app keeps across launches; `parse` reads it back.
  public var saved: Data { (try? JSONEncoder().encode(Wire(sites: names))) ?? Data() }

  /// The list on the wire; other keys beside `sites` are ignored.
  private struct Wire: Codable { let sites: [String: String] }

  private static func site(_ host: String) -> String {
    let lower = host.lowercased()
    return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
  }
}
