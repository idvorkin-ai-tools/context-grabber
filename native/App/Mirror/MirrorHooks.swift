//  The mirror's launch hook (docs/TESTING.md).

import ContextCore

extension AppModel {
  /// Today on screen, a grab of the fixture week (moved to this week), both exports written to
  /// Documents/exports/; GRABBER_METRIC=<key> then opens that metric's sheet, for a screenshot.
  func runMirrorHook(_ mode: String, metric: MetricKey?) {
    mirror.hookStatus = "running"  // before Today appears, so its own grab waits for the hook's
    openToday(from: "hook")
    Task {
      await mirror.runFixtureHook(mode)
      if let metric { openMetric(metric, from: "hook") }
    }
  }
}
