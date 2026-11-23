//  Story 1168 (bead context-grabber-uktm): the board's handling of a change to the ink, when it takes a quarter of a
//  second or more, says in the log how long each part of it took (`paper_ink_slow`), so a stall on a full board is
//  pinned to its part before anything is fixed.

import ContextCore
import QuartzCore

extension PaperBoardController {
  /// The handling that is slow enough to name its parts.
  static let slowInkMs = 250

  /// Called once the change has been handled, the deferred step included.
  func logSlowInk(_ laps: StepLaps, change: PaperProbe.InkChange) {
    let now = CACurrentMediaTime()
    let since = lastInkAt.map { ms(now - $0) }
    lastInkAt = now
    guard let slow = laps.report(overMs: Self.slowInkMs) else { return }
    var event: [String: Any] = [
      "action": "paper_ink_slow", "board": model.board.id, "total_ms": slow.totalMs, "laps": slow.laps,
      "strokes": inkFrames.count, "added": change.added.count, "moved": change.moved.count,
      "removed": change.removed.count,
    ]
    if let since { event["since_ink_ms"] = since }
    log.event("whiteboard", event)
  }
}
