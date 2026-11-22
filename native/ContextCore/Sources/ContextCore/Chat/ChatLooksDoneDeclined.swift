//  Larry's *Looks done* proposals Igor turned down on this device (#1098, stories 314, 1120, 1121): a swipe's *Not
//  done*, or a proposal left unticked when a Review's *Archive (N)* is tapped. The Cockpit keeps its proposal (it has no
//  way to take one off), so the phone hides it until the Cockpit's list no longer carries it.

import Foundation

public struct ChatLooksDoneDeclined: Equatable, Sendable {
  /// Where this device remembers what it turned down.
  public static let settingKey = "chat_looks_done_declined"

  public private(set) var keys: Set<String>

  public init(_ keys: Set<String> = []) { self.keys = keys }

  /// A remembered value; nothing for anything unreadable.
  public static func restored(_ saved: String?) -> ChatLooksDoneDeclined {
    ChatLooksDoneDeclined(saved.flatMap { try? JSONDecoder().decode(Set<String>.self, from: Data($0.utf8)) } ?? [])
  }

  /// What to remember.
  public var saved: String {
    (try? JSONEncoder().encode(keys.sorted())).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
  }

  /// Turns these proposals down. Returns the ones not already turned down.
  @discardableResult
  public mutating func decline(_ declined: [String]) -> [String] {
    let new = declined.filter { !keys.contains($0) }
    keys.formUnion(new)
    return new
  }

  /// A list the Cockpit just answered: a turned-down thread whose proposal the Cockpit no longer carries (cleared by a
  /// message, archived, finished, or gone) is forgotten, so Larry's next proposal shows; then every turned-down mark is
  /// taken off. Only a list that is shown may forget: a stale or cancelled read never reaches here.
  public mutating func fresh(_ rows: [ChatSummary]) -> [ChatSummary] {
    let proposed = Set(ChatListSelection.looksDone(rows).map(\.key))
    keys.formIntersection(proposed)
    return masked(rows)
  }

  /// The rows with every turned-down mark off: the one place the row, the Review line, Review's ticks and
  /// *Recommendations* all read it from.
  public func masked(_ rows: [ChatSummary]) -> [ChatSummary] {
    guard !keys.isEmpty else { return rows }
    return rows.map { keys.contains($0.key) && $0.looksDone ? $0.declined() : $0 }
  }
}

extension ChatSummary {
  /// The same row with Larry's proposal turned down on this device.
  public func declined() -> ChatSummary {
    ChatSummary(
      key: key, title: title, count: count, lastTs: lastTs, lastWho: lastWho, lastText: lastText, unread: unread,
      done: done, archived: archived, looksDone: false, pinned: pinned, skill: skill, lastAuthor: lastAuthor)
  }
}

/// The leading swipe on a live row (#1098, story 1120): *Not done* while it says *Looks done*.
public enum ChatLooksDoneSwipe {
  public static func offers(_ thread: ChatSummary) -> Bool { thread.showsLooksDone && !thread.pinned }
}
