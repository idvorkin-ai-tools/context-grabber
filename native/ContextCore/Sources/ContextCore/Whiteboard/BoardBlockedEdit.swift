//  When Larry's edit is blocked (spec 2026-11-16-whiteboard-board-ops-design.md, *When Larry's edit is blocked*;
//  stories 970–972): the chip that says a change of his was refused, and what each way out of it does. The board's
//  model owns the chip's view and the turn Retry starts; this says when it shows and goes.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardBlockedEdit: Equatable, Sendable {
  /// What the chip says.
  public static let text = "Larry's edit blocked"

  /// The refused change on show, by its label; nil with no chip.
  public private(set) var label: String?
  /// Why it was refused.
  public private(set) var reason = ""

  public init() {}

  public var showing: Bool { label != nil }

  /// A change of Larry's was refused. Nobody sees a change dropped because the board closed, so it shows nothing. True
  /// when the chip shows.
  @discardableResult
  public mutating func refused(label: String, reason: String) -> Bool {
    guard reason != "board_closed" else { return false }
    self.label = label
    self.reason = reason
    return true
  }

  /// A later change of his applied: the chip goes. True when it was showing.
  @discardableResult
  public mutating func applied() -> Bool { clear() }

  /// Retry: the caller has handed Larry the board, so the chip goes. True when it was showing.
  @discardableResult
  public mutating func retry() -> Bool { clear() }

  /// ×: the chip goes and nothing is asked. True when it was showing.
  @discardableResult
  public mutating func dismissed() -> Bool { clear() }

  private mutating func clear() -> Bool {
    defer { label = nil }
    return label != nil
  }
}
