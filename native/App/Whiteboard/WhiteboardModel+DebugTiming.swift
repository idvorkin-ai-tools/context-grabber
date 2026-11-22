//  What the board says about its own sending, for the Cockpit's board debug page (story 1112, bead context-grabber-7zmj):
//  the build on every picture and events batch, and the mic's timings going out among the events.

import ContextCore
import Foundation

extension WhiteboardModel {
  /// The app's build as a shake report names it: `<sha> <branch>`.
  static var buildLine: String { "\(BuildInfo.sha) \(BuildInfo.branch)" }

  /// Now, unix ms, for the mic's clock.
  static var micNowMs: Int64 { unixMs() }

  /// Spoken words taken and not yet sent go among the events now: the picture or batch about to be taken carries them.
  func micTimingsGo() {
    for event in micClock.sent(t: Self.micNowMs) { events.record(event) }
  }
}
