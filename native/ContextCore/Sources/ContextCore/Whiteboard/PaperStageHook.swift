//  Story 1020 (bead 8o93): the grammar of the bare PaperKit stage's launch hook, for the touch contracts' UI tests.

import Foundation

/// `GRABBER_PAPER_STAGE=<draw|select>[,cancel]`: a bare PaperKit paper, set up as the board sets it up, over the app, so a
/// UI test's real touch reaches real PaperKit with none of the board's own handling in between. `draw` leaves a finger
/// drawing, as on the simulator; `select` sets it as the board does while marks show (a finger selects, it doesn't
/// draw). `cancel` has the stage call off a touch held down past a beat, as the system does a palm's.
public struct PaperStageHook: Equatable, Sendable {
  public enum Finger: String, Sendable { case draw, select }

  public var finger: Finger
  public var cancelsHeldTouch: Bool

  public init(finger: Finger, cancelsHeldTouch: Bool = false) {
    self.finger = finger
    self.cancelsHeldTouch = cancelsHeldTouch
  }

  /// Nil when the hook isn't set, or its finger isn't one of the two.
  public init?(_ env: [String: String]) {
    guard let spec = env["GRABBER_PAPER_STAGE"] else { return nil }
    let parts = spec.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard let first = parts.first, let finger = Finger(rawValue: first) else { return nil }
    self.init(finger: finger, cancelsHeldTouch: parts.dropFirst().contains("cancel"))
  }
}
