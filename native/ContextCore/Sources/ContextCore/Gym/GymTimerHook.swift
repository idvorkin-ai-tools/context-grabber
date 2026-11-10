//  The Gym Timer's launch hooks (docs/TESTING.md). Pure; the app's `runTimerHook` opens the timer.

import Foundation

/// One of three, the first that is set. `GRABBER_TIMER=<chip id>` starts that preset as a tap on a widget tile would,
/// and `GRABBER_TIMER=<work>,<rest>,<rounds>` runs that shape as Custom (`GRABBER_TURN` names how the device lies).
/// `GRABBER_TIMER_SETTINGS=1` opens the timer with its settings up. `GRABBER_TIMER_DIAL=<style>` alone opens it on
/// Custom, not started (story 184). `GRABBER_COUNT_VOICE` and the dial ride whichever it is.
public enum GymTimerHook: Equatable, Sendable {
  case start(preset: String?, custom: CustomPreset?, turn: DeviceTurn?, voice: CountVoice?, dial: DialStyle?)
  case settings(voice: CountVoice?, dial: DialStyle?)
  case dial(DialStyle, voice: CountVoice?)

  public init?(_ env: [String: String]) {
    let voice = env["GRABBER_COUNT_VOICE"].flatMap(CountVoice.init(rawValue:))
    let dial = env["GRABBER_TIMER_DIAL"].flatMap(DialStyle.init(rawValue:))
    if let spec = env["GRABBER_TIMER"], !spec.isEmpty {
      let turn = env["GRABBER_TURN"].flatMap(DeviceTurn.init(rawValue:))
      let numbers = spec.split(separator: ",").compactMap { Int($0) }
      if numbers.count == 3 {
        let custom = CustomPreset(work: numbers[0], rest: numbers[1], rounds: numbers[2])
        self = .start(preset: nil, custom: custom, turn: turn, voice: voice, dial: dial)
      } else {
        self = .start(preset: spec, custom: nil, turn: turn, voice: voice, dial: dial)
      }
    } else if env["GRABBER_TIMER_SETTINGS"] == "1" {
      self = .settings(voice: voice, dial: dial)
    } else if let dial {
      self = .dial(dial, voice: voice)
    } else {
      return nil
    }
  }
}
