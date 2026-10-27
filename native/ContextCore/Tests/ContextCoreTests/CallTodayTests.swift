//  Story 217: today so far rides a Direct call's start frame.

import XCTest

@testable import ContextCore

final class CallTodayTests: XCTestCase {
  private let now = la.localTime(year: 2026, month: 3, day: 15, hour: 9, minute: 30)
  private let strip: [DailyItem: Int] = [.gym: 1, .meditation: 0, .journal: 1, .balloons: 3, .magic: 0]

  private func snapshot(at ms: Double) -> MirrorSnapshot {
    var h = HealthData()
    h.steps = 4210.6
    h.sleepHours = 6.54
    h.exerciseMinutes = 31.2
    h.meditationMinutes = 10
    h.workouts = [
      WorkoutEntry(activityType: "Functional Strength", durationMinutes: 44.6, energyBurned: nil, distanceKm: nil)
    ]
    return MirrorSnapshot(timestamp: isoString(ms), health: h)
  }

  private func object(_ text: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]
  }

  func testATodayGrabGivesItsNumbersAndItsAge() {
    let today = CallToday.build(snapshot: snapshot(at: now - 12 * 60_000), strip: strip, now: now, clock: la)
    XCTAssertEqual(today.date, "2026-03-15")
    XCTAssertEqual(today.grabAgeMinutes, 12)
    XCTAssertEqual(today.steps, 4211)
    XCTAssertEqual(today.sleepHours, 6.5)
    XCTAssertEqual(today.exerciseMinutes, 31)
    XCTAssertEqual(today.mindfulMinutes, 10)
    XCTAssertEqual(today.workouts, [CallToday.Workout(type: "Functional Strength", minutes: 45)])
    XCTAssertEqual(today.description, "grab 12 min old")
  }

  /// Larry never hears yesterday's numbers as today's: a grab from before midnight gives the strip only.
  func testAGrabFromAnEarlierDayGivesTheStripOnly() {
    let yesterday = la.localTime(year: 2026, month: 3, day: 14, hour: 23, minute: 50)
    let today = CallToday.build(snapshot: snapshot(at: yesterday), strip: strip, now: now, clock: la)
    XCTAssertNil(today.asOf)
    XCTAssertNil(today.steps)
    XCTAssertNil(today.sleepHours)
    XCTAssertEqual(today.workouts, [])
    XCTAssertEqual(today.strip, strip)
    XCTAssertEqual(today.description, "strip only")
    XCTAssertEqual(CallToday.build(snapshot: nil, strip: strip, now: now, clock: la).description, "strip only")
  }

  func testTheFrameCarriesTodayInTheBridgesSnakeCase() {
    let today = CallToday.build(snapshot: snapshot(at: now - 60_000), strip: [.balloons: 2], now: now, clock: la)
    let frame = object(CallProtocol.startFrame(backend: .direct, today: today))
    let fields = frame["today"] as? [String: Any] ?? [:]
    XCTAssertEqual(fields["date"] as? String, "2026-03-15")
    XCTAssertEqual(fields["grab_age_min"] as? Int, 1)
    XCTAssertEqual(fields["steps"] as? Int, 4211)
    XCTAssertEqual(fields["sleep_hours"] as? Double, 6.5)
    XCTAssertEqual(fields["exercise_min"] as? Int, 31)
    XCTAssertEqual(fields["mindful_min"] as? Int, 10)
    XCTAssertEqual((fields["workouts"] as? [[String: Any]])?.first?["minutes"] as? Int, 45)
    XCTAssertEqual(
      fields["strip"] as? [String: Int], ["gym": 0, "meditation": 0, "journal": 0, "balloons": 2, "magic": 0],
      "every item, zero when untouched")

    let bare = object(
      CallProtocol.startFrame(
        backend: .direct, today: CallToday.build(snapshot: nil, strip: [:], now: now, clock: la)))
    let bareFields = bare["today"] as? [String: Any] ?? [:]
    XCTAssertTrue(bareFields["steps"] is NSNull, "a number the phone does not have is null")
    XCTAssertTrue(bareFields["as_of"] is NSNull)
    XCTAssertNil(object(CallProtocol.startFrame(backend: .direct))["today"])
  }

  func testOnlyADirectCallsStartCarriesTheDay() {
    let today = CallToday.build(snapshot: snapshot(at: now - 60_000), strip: strip, now: now, clock: la)

    let direct = CallHarness()
    direct.session.setToday(today)
    direct.session.start(.direct)
    direct.socket.open()
    XCTAssertNotNil(direct.socket.frames.first?["today"])
    XCTAssertEqual(direct.last("call_sent")?["today"] as? String, "grab 1 min old")

    let eleven = CallHarness()
    eleven.session.setToday(today)
    eleven.session.start(.eleven)
    eleven.socket.open()
    XCTAssertNil(eleven.socket.frames.first?["today"])
    XCTAssertNil(eleven.last("call_sent")?["today"])
  }
}
