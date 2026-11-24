//  The day, summed up, to Larry (stories 1611-1613): one record per day of the week, sent once and again only when it
//  changes, places by name only, a refused reading empty on its own. Against a fake Cockpit speaking the shape agreed
//  with Larry on 2026-11-24 (Cockpit thread igor2-88g.1620, msg 567ab576db57).

import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private let pacific = TimeZone(identifier: "America/Los_Angeles") ?? .current
private let clock = LocalClock(timeZone: pacific)
private let hour = 3_600_000.0
/// Tuesday 24 November 2026, 09:00 Pacific.
private let tuesdayNine = clock.localTime(year: 2026, month: 11, day: 24, hour: 9)
private let days = ["2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21", "2026-11-22", "2026-11-23", "2026-11-24"]

private final class FakeCockpit: @unchecked Sendable {
  var answers: [(Int, String)]
  var failWith: Error?
  private(set) var bodies: [[String: Any]] = []
  private(set) var paths: [String] = []

  init(_ answers: [(Int, String)] = []) { self.answers = answers }

  var transport: DailyPushSender.Transport {
    { [self] request in
      paths.append(request.url?.path ?? "")
      if let body = request.httpBody, let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] {
        bodies.append(json)
      }
      if let failWith { throw failWith }
      let (status, body) = answers.isEmpty ? (200, #"{"ok": true}"#) : answers.removeFirst()
      let url = try XCTUnwrap(request.url)
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
      )
    }
  }
}

/// A week as a grab reads it: steps every day, Monday's night from the Watch, a strength workout on Saturday.
private func aWeek(weightMonday: Double? = 82.1, nightSource: String = "Igor's Apple Watch") -> MirrorSnapshot {
  var night = SleepDaily(date: "2026-11-23")
  night.totalHours = 7.2
  night.coreHours = 4
  night.deepHours = 1.2
  night.remHours = 2
  night.awakeHours = 0.4
  let bed = clock.localTime(year: 2026, month: 11, day: 23, hour: 23)
  night.bedtime = isoString(bed)
  night.wakeTime = isoString(bed + 8 * hour)
  night.samples = [SleepSample(start: bed, end: bed + 8 * hour, value: 3, source: nightSource)]
  let weekly: [MetricKey: WeeklySeries] = [
    .steps: .daily(days.map { DailyValue(date: $0, value: 8000) }),
    .weight: .daily(days.map { DailyValue(date: $0, value: $0 == "2026-11-23" ? weightMonday : nil) }),
    .exerciseMinutes: .daily(days.map { DailyValue(date: $0, value: 30) }),
  ]
  let lift = WorkoutEntry(
    activityType: "Functional Strength", durationMinutes: 45, energyBurned: 300, distanceKm: nil,
    startTime: isoString(clock.localTime(year: 2026, month: 11, day: 21, hour: 7)),
    endTime: isoString(clock.localTime(year: 2026, month: 11, day: 21, hour: 7) + 0.75 * hour))
  return MirrorSnapshot(
    timestamp: isoString(tuesdayNine), health: HealthData(), weekly: weekly,
    sleepBundle: SleepDetailedBundle(bySource: [:], merged: [night]), workoutsByDay: ["2026-11-21": [lift]])
}

/// Monday: two hours at the gym, an hour at a place never named.
private func monday() -> PlaceDaySummary {
  let start = clock.localTime(year: 2026, month: 11, day: 23, hour: 7)
  return PlaceDaySummary(
    dateKey: "2026-11-23",
    places: [.init(placeId: "Kettlebility", totalMinutes: 120), .init(placeId: "Place 3", totalMinutes: 60)],
    visits: [
      PlaceVisit(placeId: "Kettlebility", startTime: start, endTime: start + 2 * hour, durationMinutes: 120),
      PlaceVisit(placeId: "Place 3", startTime: start + 3 * hour, endTime: start + 4 * hour, durationMinutes: 60),
    ],
    elapsedMinutes: 1440, totalStayMinutes: 180, transitMinutes: 20, noDataMinutes: 600, stripSegments: [],
    dayLengthMs: 24 * hour)
}

private func records(
  _ snap: MirrorSnapshot = aWeek(), strip: [DailyItem: [String: Int]] = [:], now: Double = tuesdayNine
) -> [DailyPushRecord] {
  let habits = Dictionary(
    uniqueKeysWithValues: days.map { day in
      (
        day,
        DailyPush.habits(
          date: day, strip: strip, activity: [], workouts: snap.workoutsByDay[day] ?? [], mindfulMinutes: nil)
      )
    })
  return DailyPush.week(
    snap, places: ["2026-11-23": monday()], namedPlaces: ["Kettlebility", "Home"], habits: habits
  ).map { DailyPush.record($0, device: "phone-1", build: "abc123", now: now, clock: clock) }
}

private func body(_ record: DailyPushRecord) throws -> [String: Any] {
  try XCTUnwrap(JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any])
}

final class DailyPushTests: XCTestCase {
  private var lines: [[String: Any]] = []
  private func log(_ name: String, _ fields: [String: Any]) {
    XCTAssertEqual(name, "daily_push")
    lines.append(fields)
  }

  private func sender(_ cockpit: FakeCockpit) -> DailyPushSender {
    DailyPushSender(cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
  }

  // Story 1611: the week goes once, oldest first, to /daily.
  func testTheWeekGoesOnceOldestFirst() async {
    var state = DailyPushState()
    state.consider(records())
    let cockpit = FakeCockpit()
    let first = await sender(cockpit).send(state, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    XCTAssertEqual(cockpit.bodies.compactMap { $0["date"] as? String }, days)
    XCTAssertEqual(Set(cockpit.paths), ["/daily"])
    XCTAssertEqual(first.ended, .done)
    XCTAssertTrue(first.state.waiting.isEmpty)
    // Nothing changed: the next grab queues nothing, and nothing goes.
    var again = first.state
    XCTAssertEqual(again.consider(records()), [])
    let second = FakeCockpit()
    _ = await sender(second).send(again, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    XCTAssertTrue(second.bodies.isEmpty)
  }

  // Story 1611: what a day says, in the agreed shape.
  func testMondaysRecordSaysTheNightThePlacesAndTheHabits() throws {
    let strip: [DailyItem: [String: Int]] = [.journal: ["2026-11-23": 1], .balloons: ["2026-11-23": 3]]
    let record = try XCTUnwrap(records(strip: strip).first { $0.date == "2026-11-23" })
    let json = try body(record)
    XCTAssertEqual(json["id"] as? String, "phone-1-2026-11-23-\(record.hash)")
    XCTAssertEqual(json["type"] as? String, "day")
    XCTAssertEqual(json["tz"] as? String, "America/Los_Angeles")
    XCTAssertEqual(json["final"] as? Bool, false, "Monday's night can still change until Tuesday noon")
    let health = try XCTUnwrap(json["health"] as? [String: Any])
    let sleep = try XCTUnwrap(health["sleep"] as? [String: Any])
    XCTAssertEqual(sleep["asleep_h"] as? Double, 7.2)
    XCTAssertEqual(sleep["in_bed_h"] as? Double, 8)
    XCTAssertEqual(sleep["asleep_source"] as? String, "watch")
    XCTAssertEqual(sleep["bedtime"] as? String, "2026-11-23T23:00:00-08:00")
    XCTAssertEqual(health["steps"] as? Double, 8000)
    XCTAssertEqual(health["weight_kg"] as? Double, 82.1)
    let places = try XCTUnwrap(json["places"] as? [String: Any])
    let visits = try XCTUnwrap(places["visits"] as? [[String: Any]])
    XCTAssertEqual(visits.map { $0["place"] as? String }, ["Kettlebility"])
    XCTAssertEqual(places["unnamed_min"] as? Int, 60)
    let habits = try XCTUnwrap(json["habits"] as? [String: Any])
    XCTAssertEqual(Set(habits.keys), Set(DailyItem.allCases.map(\.rawValue)))
    XCTAssertEqual((habits["journal"] as? [String: Any])?["done"] as? Bool, true)
    XCTAssertEqual((habits["journal"] as? [String: Any])?["by"] as? [String], ["tap"])
    XCTAssertEqual((habits["balloons"] as? [String: Any])?["count"] as? Int, 3)
  }

  // Story 1611: a strength workout in Health makes the gym count, by Health.
  func testSaturdaysLiftCountsAsAGymDayByHealth() throws {
    let record = try XCTUnwrap(records().first { $0.date == "2026-11-21" })
    let habits = try XCTUnwrap(try body(record)["habits"] as? [String: Any])
    XCTAssertEqual((habits["gym"] as? [String: Any])?["by"] as? [String], ["health"])
    XCTAssertEqual(try body(record)["final"] as? Bool, true)
  }

  // Story 1612: a habit ticked for yesterday sends yesterday again, and nothing else.
  func testAHabitTickedLaterSendsOnlyThatDayAgain() async {
    var state = DailyPushState()
    state.consider(records())
    let first = await sender(FakeCockpit()).send(state, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    var after = first.state
    let later = tuesdayNine + 2 * hour
    let queued = after.consider(records(strip: [.journal: ["2026-11-23": 1]], now: later))
    XCTAssertEqual(queued, ["2026-11-23"])
    let cockpit = FakeCockpit()
    _ = await sender(cockpit).send(after, today: "2026-11-24", now: { jsDate(later) }, log: log)
    XCTAssertEqual(cockpit.bodies.compactMap { $0["date"] as? String }, ["2026-11-23"])
  }

  // Story 1612: today goes at most every fifteen minutes; a past day as soon as it changes.
  func testTodayWaitsFifteenMinutesBetweenSends() {
    var state = DailyPushState()
    state.sentAt["2026-11-24"] = tuesdayNine
    state.consider(records())
    let due = state.due(now: tuesdayNine + 5 * 60_000, today: "2026-11-24").map(\.date)
    XCTAssertFalse(due.contains("2026-11-24"))
    XCTAssertTrue(due.contains("2026-11-23"))
    XCTAssertTrue(
      state.due(now: tuesdayNine + 15 * 60_000, today: "2026-11-24").map(\.date).contains("2026-11-24"))
  }

  // Story 1612: only the newest version of a day waits.
  func testANewerVersionOfADayReplacesTheOneWaiting() {
    var state = DailyPushState()
    state.consider(records())
    state.consider(records(strip: [.magic: ["2026-11-22": 2]]))
    XCTAssertEqual(state.waiting.filter { $0.date == "2026-11-22" }.count, 1)
    XCTAssertTrue(state.waiting.first { $0.date == "2026-11-22" }?.json.contains(#""count":2"#) == true)
  }

  // Story 1613: no coordinates anywhere, and a refused reading is empty on its own.
  func testNoCoordinatesAndARefusedReadingIsEmptyAlone() throws {
    let record = try XCTUnwrap(records(aWeek(weightMonday: nil)).first { $0.date == "2026-11-23" })
    for word in ["latitude", "longitude", "radius", "centroid", "Place 3"] {
      XCTAssertFalse(record.json.contains(word), word)
    }
    let health = try XCTUnwrap(try body(record)["health"] as? [String: Any])
    XCTAssertTrue(health["weight_kg"] is NSNull)
    XCTAssertEqual(health["steps"] as? Double, 8000)
  }

  // The same content is the same id, whenever it is worked out: a resend is a duplicate on the Cockpit.
  func testTheIdIsTheContentNotTheTimeItWasWorkedOut() {
    let a = records(now: tuesdayNine + 13 * hour).map(\.hash)
    let b = records(now: tuesdayNine + 14 * hour).map(\.hash)
    XCTAssertEqual(a, b)
  }

  func testWhereTheNightWasMeasured() {
    XCTAssertEqual(DailyPush.sourceKind("Igor's Apple Watch"), "watch")
    XCTAssertEqual(DailyPush.sourceKind("Igor's iPhone"), "phone")
    XCTAssertEqual(DailyPush.sourceKind("Health"), "manual")
    XCTAssertEqual(DailyPush.sourceKind("AutoSleep"), "other")
  }

  // The route not there yet keeps everything waiting; a refusal is not retried until the day changes.
  func testNotYetWaitsAndARefusalIsNotRetried() async {
    var state = DailyPushState()
    state.consider(records())
    let notYet = FakeCockpit([(404, "")])
    let waited = await sender(notYet).send(state, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    XCTAssertEqual(waited.ended, .retry)
    XCTAssertEqual(waited.state.waiting.count, 7)
    XCTAssertTrue((lines.last?["reason"] as? String)?.hasPrefix(DailyPushWire.notYet) == true)
    let refusing = FakeCockpit([(400, #"{"reason": "bad day"}"#)])
    let refused = await sender(refusing).send(state, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    // The oldest day was refused and the other six went on.
    XCTAssertEqual(refusing.bodies.count, 7)
    XCTAssertTrue(refused.state.waiting.isEmpty)
    XCTAssertEqual(lines.first { $0["action"] as? String == "refused" }?["date"] as? String, "2026-11-18")
    var again = refused.state
    XCTAssertEqual(again.consider(records()), [], "the refused day is not queued again until it changes")
  }

  func testAServerErrorWaitsAndTriesAgainLater() async {
    var state = DailyPushState()
    state.consider(records())
    let cockpit = FakeCockpit([(200, #"{"ok": true}"#), (503, "")])
    let result = await sender(cockpit).send(state, today: "2026-11-24", now: { jsDate(tuesdayNine) }, log: log)
    XCTAssertEqual(result.ended, .retry)
    XCTAssertEqual(result.state.waiting.count, 6)
    XCTAssertEqual(lines.last?["action"] as? String, "waiting")
  }
}
