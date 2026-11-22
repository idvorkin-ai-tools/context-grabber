//  How a jump to a board learns it can open (#1137; spec 2026-10-25-native-chat-design.md, story 1137): a chat
//  picture's *Jump to board*, *Board* in a thread's bar, a board link.

import Foundation

/// A board this device draws, whose drawing is here, opens at once: no other device draws on it, so iCloud has nothing
/// newer for it (`BoardIndex.merge` leaves this device's own boards as they are). Another device's board, or one whose
/// drawing isn't here, asks iCloud first. A board just found for a jump isn't asked about again as the boards come up
/// to open it, so a jump asks iCloud at most once (it asked twice, about 700 ms each, on the iPad).
public struct BoardFind: Sendable {
  /// What a find did before deciding: the session log's `icloud`.
  public enum Ask: String, Sendable {
    /// iCloud was asked first.
    case asked
    /// This device's own board, here: opened without asking.
    case ownHere = "own_here"
    /// Found for this same jump a moment ago: not asked again.
    case justAsked = "just_asked"
  }

  /// How long a board found for a jump counts as just found: the cover going down and the boards coming up take about
  /// a second and a half.
  public static let handOffSeconds: Double = 10

  private var found: String?
  private var foundAt: Double = 0

  public init() {}

  /// Whether to ask iCloud before deciding the board can open, at `now` (seconds on any steady clock).
  public mutating func ask(_ id: String, index: BoardIndex, device: String, now: Double) -> Ask {
    defer { found = nil }
    if found == id, now - foundAt >= 0, now - foundAt <= Self.handOffSeconds { return .justAsked }
    guard let board = index.board(id), board.device == device, board.current else { return .asked }
    return .ownHere
  }

  /// The board was found and is about to open: the next find of it, as the boards come up, needn't ask again.
  public mutating func opens(_ id: String, now: Double) {
    found = id
    foundAt = now
  }
}
