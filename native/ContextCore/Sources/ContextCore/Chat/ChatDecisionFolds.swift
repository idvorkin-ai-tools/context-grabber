//  Folded decision cards (spec 2026-11-14-chat-decision-cards-design.md, *Folding a card*; story 1130, bead
//  context-grabber-fjh0): which asks' cards Igor folded to one line, remembered on the device until he opens them again.

/// The asks whose cards are folded, oldest fold first. Kept as a list so the oldest go once it holds `cap`: a fold
/// outlives its ask (an answered, closed or abandoned ask is never shown again), and a list read only while online
/// can't say which asks are gone (offline shows none, a snoozed one comes back).
public struct ChatDecisionFolds: Equatable, Sendable {
  public static let cap = 300
  public private(set) var ids: [String]

  public init(_ ids: [String] = []) {
    self.ids = Array(Self.unique(ids).suffix(Self.cap))
  }

  public func isFolded(_ ask: String) -> Bool { ids.contains(ask) }

  /// Folds or opens one ask's card; false when it was already so. A fold goes last, as the newest.
  @discardableResult
  public mutating func set(_ ask: String, folded: Bool) -> Bool {
    guard folded != isFolded(ask) else { return false }
    if folded {
      ids.append(ask)
      if ids.count > Self.cap { ids.removeFirst(ids.count - Self.cap) }
    } else {
      ids.removeAll { $0 == ask }
    }
    return true
  }

  private static func unique(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
  }
}
