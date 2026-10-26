//  Speaking a message in Chat (#448, chat spec "Speaking a message"): the platform-free half of the thread's mic.
//  The words come from BugKit's dictation (Apple's recognizer, the problem report's); this is its limit and its clock.

import Foundation

public enum ChatVoice {
  /// The longest recording (Igor, 2026-10-26): at this it stops on its own, as if he had tapped stop.
  public static let limit: TimeInterval = 5 * 60

  /// The quiet line under the bar after the limit stopped a recording.
  public static var cappedLine: String { "Stopped at \(Int(limit) / 60) minutes." }

  /// The recording button's clock: `0:07`, `1:12`.
  public static func elapsed(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):" + String(format: "%02d", s % 60)
  }
}
