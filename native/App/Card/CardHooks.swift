//  The card screen's launch hook (docs/TESTING.md).

import ThinkACardCore

extension AppModel {
  /// Story 220: the card screen with *Drill the stack* already tapped, in that direction.
  func runDrillHook(_ spec: String) {
    guard let mode = StackDrill.Mode(rawValue: spec) else { return }
    drillOnOpen = mode
    openCard(think: false, from: "hook")
  }
}
