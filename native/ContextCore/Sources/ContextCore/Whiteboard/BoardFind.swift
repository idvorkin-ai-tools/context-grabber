//  How a jump to a board learns it can open (#1137; spec 2026-10-25-native-chat-design.md, story 1137): a chat
//  picture's *Jump to board*, *Board* in a thread's bar, a board link.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

/// A board this device draws, whose drawing is here, opens at once: no other device draws on it, so iCloud can bring
/// nothing newer, only another device's delete, which `BoardIndex.merge` holds while the board is open and carries out
/// once it closes, unless it was drawn on meanwhile. Another device's board, or one whose
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
    /// iCloud was asked and hadn't answered within `answerSeconds`: decided from what is here, the sync going on
    /// (bead context-grabber-4qel). `ask` never returns it; the find logs it in place of `asked`.
    case noAnswer = "no_answer"
  }

  /// How long a find waits on iCloud before going by what is here. An answer usually takes under one second; on the
  /// simulator a launch's first answer took 11 to 19 (bead context-grabber-4qel).
  public static let answerSeconds: Double = 5

  /// Whether `work` finished within `seconds`. It runs on to its end either way; only the wait is cut short.
  public static func finishes(within seconds: Double, _ work: @escaping @Sendable () async -> Void) async -> Bool {
    let once = FirstOf()
    return await withCheckedContinuation { continuation in
      once.hold(continuation)
      let timer = Task {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        once.settle(false)
      }
      Task {
        await work()
        once.settle(true)
        timer.cancel()
      }
    }
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

/// Resumes a continuation once, with whichever answer comes first.
private final class FirstOf: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Bool, Never>?

  func hold(_ continuation: CheckedContinuation<Bool, Never>) {
    lock.lock()
    self.continuation = continuation
    lock.unlock()
  }

  func settle(_ value: Bool) {
    lock.lock()
    let waiting = continuation
    continuation = nil
    lock.unlock()
    waiting?.resume(returning: value)
  }
}
