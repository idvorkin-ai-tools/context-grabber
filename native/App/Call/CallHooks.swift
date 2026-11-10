//  The call's launch hook (docs/TESTING.md).

import Foundation

extension AppModel {
  /// A call to GRABBER_CALL's bridge (the smoke run's fake one), hung up after GRABBER_CALL_SECONDS (default 8).
  func runCallHook(seconds: Double) {
    openCall(from: "hook")
    Task {
      try? await Task.sleep(for: .seconds(1))
      call.start(from: "hook")
      try? await Task.sleep(for: .seconds(seconds))
      if call.snapshot.isActive { call.hangUp(from: "hook") }
    }
  }
}
