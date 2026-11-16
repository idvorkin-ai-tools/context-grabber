//  Where a board's changes come from (spec 2026-11-16-whiteboard-board-ops-design.md, *Driven from the web or from the
//  app*, story 819; Igor, 2026-11-16: ops can be web-driven or locally driven). Every source turns what it hears into
//  batches for the one applier (`BoardOpApplier`), so Igor sees the same push, text and undo from either. Today's only
//  source is Larry's board replies; a source running Larry's own board rules inside the app takes the board's events the
//  same way, and covers a subset still to be decided.

import Foundation

/// What a board hands its sources: Larry's rows from a look at the thread, or one of its own events as it happens.
public enum BoardOpInput: Sendable {
  case rows([WhiteboardMarks.Row])
  case event(BoardEvent)
}

public protocol BoardOpSource {
  /// For the log: `web`, `local`.
  var name: String { get }
  /// The batches this input brings, oldest first. A source never needs to remember what applied: the applier does.
  mutating func batches(from input: BoardOpInput) -> [BoardOps.Batch]
}

/// Larry's changes on his board replies, read over the network (`ops` on a row of the board's thread).
public struct WebBoardOpSource: BoardOpSource {
  public let name = "web"
  private var seen: Set<String>?

  public init() {}

  /// The first look offers only the newest row's batch, as the marks do (a batch already handled is ignored by the
  /// applier); after that, each new row's.
  public mutating func batches(from input: BoardOpInput) -> [BoardOps.Batch] {
    guard case .rows(let rows) = input else { return [] }
    defer { seen = Set(rows.map(\.id)) }
    guard let seen else { return rows.last(where: { $0.ops != nil })?.ops.map { [$0] } ?? [] }
    return rows.filter { !seen.contains($0.id) }.compactMap(\.ops)
  }
}
