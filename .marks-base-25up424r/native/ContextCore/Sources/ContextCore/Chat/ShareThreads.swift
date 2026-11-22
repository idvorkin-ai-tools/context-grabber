//  #587, stories 495–499 (chat spec, Sharing into a chat that is already going): which chats the share card offers
//  beside *New chat*, and what it says when it cannot read them. The list is the one thing the card asks the network;
//  what is shared still goes through the Inbox.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum ShareThreads {
  /// How many chats the card offers.
  static let limit = 5
  /// The card works without the list, so it stops hoping sooner than Chat's own read does.
  static let timeout: TimeInterval = 6

  public enum Read: Equatable, Sendable {
    /// Every live chat, not only the rows listed: the recommended one may be further down (#794).
    case threads([ChatSummary])
    case problem(String)
  }

  /// The chats a share can go into, in the list's order (the pinned one, then newest activity).
  public static func live(_ threads: [ChatSummary]) -> [ChatSummary] {
    threads.filter { !$0.done && !$0.archived }
  }

  /// The rows the card lists under *New chat*: the recommended chat first when there is one (#794), then the most
  /// recent live ones, `limit` in all.
  public static func rows(_ live: [ChatSummary], recommended: String? = nil) -> [ChatSummary] {
    let first = live.filter { $0.key == recommended }
    return Array((first + live.filter { $0.key != recommended }).prefix(limit))
  }

  public static func read(cockpit: String, transport: InboxSender.Transport) async -> Read {
    guard cockpit != ChatCockpit.nowhere else { return .problem("New chat only: \(ChatCockpit.noAddress).") }
    do {
      var request = try ChatWire.listRequest(cockpit: cockpit)
      request.timeoutInterval = timeout
      let (data, response) = try await transport(request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = ChatWire.summaries(data) else {
        return .problem("New chat only: the Cockpit answered HTTP \(status).")
      }
      return .threads(live(rows))
    } catch {
      let why = CockpitReach.isAway(error) ? "the Cockpit isn't answering" : "the chats could not be read"
      return .problem("New chat only: \(why). (\(error.localizedDescription))")
    }
  }

  /// What the list held when a share was sent, for the app's log: the card has no session log of its own. It names a
  /// same-link chat that was recommended (#794); the item's own thread says whether the share went there.
  public static func offered(_ read: Read?, recommended: String? = nil) -> String {
    switch read {
    case nil: return "reading"
    case .threads(let live):
      return "\(rows(live, recommended: recommended).count) chats" + (recommended.map { ", same link \($0)" } ?? "")
    case .problem(let why): return why
    }
  }
}
