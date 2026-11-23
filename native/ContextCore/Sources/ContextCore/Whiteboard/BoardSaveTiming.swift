//  A board's save, stage by stage, for the session log (#1044): how long the drawing took to encode, to write, its
//  picture to draw and the list to be told, what set the save off, how many strokes it held and the revision it
//  made. Never the drawing itself. The physical iPad's numbers decide whether the save's work moves off the main actor.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardSaveTiming {
  /// What set a save off: the moment after a stroke, leaving the board, or the app going to the background.
  public enum Trigger: String, CaseIterable, Sendable {
    case debounce, close, background
  }

  public let board: String
  public let trigger: Trigger
  public let strokes: Int
  /// The board's revision once the list was told (its `updated`); nil when the save didn't get that far.
  public var revision: Int64?
  private let now: () -> TimeInterval
  private var stages: [(name: String, ms: Double)] = []
  /// The stage that threw, if one did.
  private var failed: String?

  /// `now` is in seconds, from any steady clock.
  public init(board: String, trigger: Trigger, strokes: Int, now: @escaping () -> TimeInterval) {
    self.board = board
    self.trigger = trigger
    self.strokes = strokes
    self.now = now
  }

  /// `work`, timed as `stage`; one that throws is timed and named before the error goes up.
  public mutating func time<T>(_ stage: String, _ work: () throws -> T) rethrows -> T {
    let start = now()
    do {
      let result = try work()
      stages.append((stage, (now() - start) * 1000))
      return result
    } catch {
      stages.append((stage, (now() - start) * 1000))
      failed = stage
      throw error
    }
  }

  /// The `whiteboard` event's fields: `<stage>_ms` and `total_ms` to a tenth of a millisecond.
  public var fields: [String: Any] {
    func tenth(_ ms: Double) -> Double { (ms * 10).rounded() / 10 }
    var fields: [String: Any] = [
      "action": "save_timing", "board": board, "trigger": trigger.rawValue, "strokes": strokes,
      "total_ms": tenth(stages.reduce(0) { $0 + $1.ms }),
    ]
    for stage in stages { fields["\(stage.name)_ms"] = tenth(stage.ms) }
    if let revision { fields["revision"] = revision }
    if let failed { fields["failed"] = failed }
    return fields
  }
}
