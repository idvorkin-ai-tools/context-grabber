//  A board's lines on this device (spec 2026-11-01-whiteboard-design.md, *Grid lines*; stories 407–410, 652, 653): the
//  grid, ruled lines or neither, remembered per board. A new board opens with the grid (story 410, #915); a board with
//  nothing saved has none, as every board made before that did (story 888).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if !FOUNDATION_ESSENTIALS_ONLY
  public struct BoardLines: @unchecked Sendable {
    public enum Choice: Equatable, Sendable { case none, grid, ruled }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
    }

    public static func gridKey(_ board: String) -> String { "whiteboard_grid_\(board)" }
    public static func ruledKey(_ board: String) -> String { "whiteboard_ruled_\(board)" }

    /// What the board opens with. Turning one on turns the other off, so at most one is saved on; the grid wins if both are.
    public func choice(_ board: String) -> Choice {
      if defaults.bool(forKey: Self.gridKey(board)) { return .grid }
      if defaults.bool(forKey: Self.ruledKey(board)) { return .ruled }
      return .none
    }

    public func set(_ choice: Choice, board: String) {
      defaults.set(choice == .grid, forKey: Self.gridKey(board))
      defaults.set(choice == .ruled, forKey: Self.ruledKey(board))
    }

    /// A board just made here: the grid, unless `bare` (the UI tests' `GRABBER_WHITEBOARD_GRID=off`, for pixels read
    /// against plain paper).
    public func startNew(_ board: String, bare: Bool = false) {
      set(bare ? .none : .grid, board: board)
    }

    /// A board deleted or dropped here: its choice goes with it.
    public func forget(_ board: String) {
      defaults.removeObject(forKey: Self.gridKey(board))
      defaults.removeObject(forKey: Self.ruledKey(board))
    }
  }
#endif
