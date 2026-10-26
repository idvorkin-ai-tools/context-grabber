//  Story 217: today so far, for Direct Larry's start frame (spec 2026-08-28-native-call-screen-design.md, "What the
//  day has held"). Built from what the phone already has (the last grab and the daily strip), so the call never waits
//  on Health. A grab from an earlier day gives no health numbers, only the strip.

import Foundation

public struct CallToday: Equatable, Sendable {
  public struct Workout: Equatable, Sendable {
    public var type: String
    public var minutes: Int
  }

  /// The local day, `2026-10-26`.
  public var date: String
  /// When the grab the numbers come from finished, ISO 8601; nil when there is no grab from today.
  public var asOf: String?
  public var grabAgeMinutes: Int?
  public var steps: Int?
  public var sleepHours: Double?
  public var exerciseMinutes: Int?
  public var mindfulMinutes: Int?
  public var workouts: [Workout] = []
  /// The strip as the home screen shows it: a check is 1 or 0, a counter its count.
  public var strip: [DailyItem: Int]

  /// `snapshot`: the last grab, used only when it finished today. `strip`: today's values, every item present.
  public static func build(snapshot: MirrorSnapshot?, strip: [DailyItem: Int], now: Double, clock: LocalClock)
    -> CallToday
  {
    let today = clock.dateKey(now)
    var out = CallToday(date: today, strip: strip)
    guard let snapshot, let taken = parseISO(snapshot.timestamp), clock.dateKey(taken) == today else { return out }
    let h = snapshot.health
    out.asOf = snapshot.timestamp
    out.grabAgeMinutes = max(0, Int((now - taken) / 60_000))
    out.steps = h.steps.map { Int($0.rounded()) }
    out.sleepHours = h.sleepHours.map { ($0 * 10).rounded() / 10 }
    out.exerciseMinutes = h.exerciseMinutes.map { Int($0.rounded()) }
    out.mindfulMinutes = h.meditationMinutes.map { Int($0.rounded()) }
    out.workouts = h.workouts.map { Workout(type: $0.activityType, minutes: Int($0.durationMinutes.rounded())) }
    return out
  }

  /// What rides the wire, the bridge's snake_case; a number the phone does not have is null.
  var fields: [String: Any] {
    func num<T>(_ v: T?) -> Any { v.map { $0 as Any } ?? NSNull() }
    var stripFields: [String: Any] = [:]
    for item in DailyItem.allCases { stripFields[item.rawValue] = strip[item] ?? 0 }
    return [
      "date": date, "as_of": num(asOf), "grab_age_min": num(grabAgeMinutes), "steps": num(steps),
      "sleep_hours": num(sleepHours), "exercise_min": num(exerciseMinutes), "mindful_min": num(mindfulMinutes),
      "workouts": workouts.map { ["type": $0.type, "minutes": $0.minutes] as [String: Any] }, "strip": stripFields,
    ]
  }

  /// One log line, never the numbers: `grab 12 min old` or `strip only`.
  public var description: String {
    grabAgeMinutes.map { "grab \($0) min old" } ?? "strip only"
  }
}
