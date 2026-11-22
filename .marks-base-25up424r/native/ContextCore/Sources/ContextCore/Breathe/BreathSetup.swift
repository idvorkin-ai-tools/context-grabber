//  Story 241: the breath length chosen on the setup screen, as the settings remember it. A preset is its seconds;
//  Custom is its own In and Out, which never follow a preset chosen later (#200).

import Foundation

public struct BreathSetup: Equatable, Sendable {
  public static let breathKey = "breathe_breath_seconds"
  public static let customKey = "breathe_custom"
  public static let customInKey = "breathe_custom_in"
  public static let customOutKey = "breathe_custom_out"
  /// #289: the pattern chosen ("4-4-6-2"), or empty when a preset or Custom is.
  public static let patternKey = "breathe_pattern"

  /// The preset's seconds, or nil for Custom or a pattern.
  public var preset: Int?
  /// #289: a pattern, which wins over the preset and Custom while chosen.
  public var pattern: BreathPattern? = nil
  public var customIn: Int
  public var customOut: Int

  /// What the settings hold. A breath from the old slider becomes its preset if one matches, else Custom at that
  /// length both ways. `seeds` are the Custom sides the settings do not hold yet: saving them now pins them, so a
  /// preset chosen later cannot change an In or Out never touched.
  public static func restore(_ setting: (String) -> String?) -> (
    setup: BreathSetup, seeds: [(key: String, value: String)]
  ) {
    let stored = setting(breathKey).flatMap(Int.init) ?? BreathPlan.defaultBreath
    let custom = setting(customKey) == "1" || !BreathPlan.presets.contains(stored)
    let storedIn = setting(customInKey).flatMap(Int.init)
    let storedOut = setting(customOutKey).flatMap(Int.init)
    var seeds: [(key: String, value: String)] = []
    if storedIn == nil { seeds.append((customInKey, String(stored))) }
    if storedOut == nil { seeds.append((customOutKey, String(stored))) }
    let pattern = BreathPattern.named(setting(patternKey))
    return (
      BreathSetup(
        preset: custom || pattern != nil ? nil : stored, pattern: pattern, customIn: storedIn ?? stored,
        customOut: storedOut ?? stored),
      seeds
    )
  }

  /// What choosing a preset's `seconds` (nil for Custom) writes, in order; `restore` reads it back as that choice.
  /// Custom's sides are seeded first, from what the settings hold now, so the preset cannot become them (#200).
  public static func writes(preset seconds: Int?, _ setting: (String) -> String?) -> [(key: String, value: String)] {
    restore(setting).seeds + [(patternKey, "")] + (seconds.map { [(breathKey, String($0))] } ?? [])
      + [(customKey, seconds == nil ? "1" : "0")]
  }

  /// #289: what choosing a pattern writes. It wins until a preset or Custom is chosen.
  public static func writes(pattern: BreathPattern) -> [(key: String, value: String)] {
    [(patternKey, pattern.key), (customKey, "0")]
  }
}
