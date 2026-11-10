//  The Gym Timer's launch hooks (docs/TESTING.md); `GymTimerHook` in ContextCore reads them.

import ContextCore

extension AppModel {
  func runTimerHook(_ hook: GymTimerHook) {
    switch hook {
    case .start(let preset, let custom, let turn, let voice, let dial):
      // A chip's id starts it as a tap on a widget tile would; "work,rest,rounds" runs that shape as Custom.
      var launch = GymTimerLaunch(autostart: true, turn: turn, voice: voice, dial: dial)
      launch.custom = custom
      launch.preset = preset
      openGymTimer(launch, from: "hook")
    case .settings(let voice, let dial):
      openGymTimer(GymTimerLaunch(voice: voice, settings: true, dial: dial), from: "hook")
    case .dial(let dial, let voice):
      // Story 184: which Custom control the timer draws upright; alone, it opens the timer on CUSTOM, not started.
      openGymTimer(GymTimerLaunch(preset: CustomPreset.id, voice: voice, dial: dial), from: "hook")
    }
  }
}
