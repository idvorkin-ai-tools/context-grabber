//  The breathing screen's launch hook (docs/TESTING.md); `BreatheHook` in ContextCore reads it.

import ContextCore

extension AppModel {
  /// "breath,cycles[,cue[,pause_at_seconds]]" begins that exact session; anything else just opens the sliders.
  func runBreatheHook(_ hook: BreatheHook) {
    var launch = BreatheLaunch()
    launch.style = hook.style
    launch.plan = hook.plan
    launch.cue = hook.cue
    launch.pauseAt = hook.pauseAt
    openBreathe(launch, from: "hook")
  }
}
