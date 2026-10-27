//  A new chat from the + (#536, chat spec "A new chat"): where the bar's next Send goes, and which first message the
//  screen follows. Each attempt at a first message is its own message with its own id, so a new try after a refusal
//  or a deletion is never taken by the Cockpit as a duplicate of the old one (Fable on #538).

import Foundation

public struct ChatNewThread: Equatable, Sendable {
  /// Where a Send goes.
  public enum Target: Equatable, Sendable {
    /// A thread the Cockpit has.
    case thread(String)
    /// Nothing sent yet (or the last first message was deleted): the Send starts the chat.
    case new
    /// The first message is on its way: the next one waits for its thread.
    case waiting
    /// Larry refused the first message: the Send starts the chat again.
    case refused(reason: String)

    /// Whether a Send now starts the chat with a fresh first message.
    public var startsChat: Bool {
      switch self {
      case .new, .refused: return true
      case .thread, .waiting: return false
      }
    }
  }

  /// The id of the last first message sent from this screen: the one it follows.
  public private(set) var sent: String?
  /// The thread that message landed in, kept once known (the phone's copy is dropped after the thread lists it).
  public private(set) var landed: String?

  public init() {}

  /// `first`: the phone's copy of the message with id `sent`, nil when none was sent or it was deleted.
  public static func target(fixedKey: String?, landed: String?, first: InboxItem?) -> Target {
    if let key = fixedKey ?? landed { return .thread(key) }
    guard let first else { return .new }
    if let reason = first.refused { return .refused(reason: reason) }
    if let thread = first.chatThread { return .thread(thread) }
    return .waiting
  }

  /// A Send at `target`: the id for a fresh first message, now the one this screen follows; nil when the Send goes
  /// to a thread or must wait.
  public mutating func attempt(at target: Target, id: String = UUID().uuidString.lowercased()) -> String? {
    guard target.startsChat else { return nil }
    sent = id
    return id
  }

  /// The followed first message reached the Cockpit in `thread`: from now on this screen is that thread.
  public mutating func land(in thread: String) {
    if landed == nil { landed = thread }
  }
}
