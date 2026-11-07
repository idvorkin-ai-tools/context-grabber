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
    case threads([ChatSummary])
    case problem(String)
  }

  /// The live chats, in the list's order (the pinned one, then newest activity).
  public static func recent(_ threads: [ChatSummary]) -> [ChatSummary] {
    Array(threads.filter { !$0.done && !$0.archived }.prefix(limit))
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
      return .threads(recent(rows))
    } catch {
      let why = CockpitReach.isAway(error) ? "the Cockpit isn't answering" : "the chats could not be read"
      return .problem("New chat only: \(why). (\(error.localizedDescription))")
    }
  }

  /// What the list held when a share was sent, for the app's log: the card has no session log of its own.
  public static func offered(_ read: Read?) -> String {
    switch read {
    case nil: return "reading"
    case .threads(let rows): return "\(rows.count) chats"
    case .problem(let why): return why
    }
  }
}
