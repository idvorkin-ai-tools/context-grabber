//  Igor, 2026-11-01: the simulator smoke plays the timer's counts, the breathing voice and the call through the Mac's
//  speakers. GRABBER_SILENT=1 (the smoke sets it on every launch) turns this app's own sound to zero and nothing else:
//  every cue still plays and logs as played, so the checks read the same, and the Mac's other audio is untouched.

import Foundation

enum TestAudio {
  static let silent = ProcessInfo.processInfo.environment["GRABBER_SILENT"] == "1"
  /// A player's volume: as asked, or nothing under the smoke.
  static func volume(_ asked: Float = 1) -> Float { silent ? 0 : asked }
}
