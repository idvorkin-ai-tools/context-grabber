//  #404, story 226: the daily strip and remaining Health numbers on the usage tile.

import XCTest

@testable import ContextCore

final class TodayGlanceTests: XCTestCase {
  private func card(_ key: MetricKey, _ value: String) -> MetricCard {
    MetricCard(key: key, label: key.rawValue, value: value, sublabel: "", color: "#000000", boxPlots: [])
  }

  func testHealthNumbersKeepTheirOrderWithoutSleep() {
    let cards = [
      card(.hrv, "65.2 ms"), card(.sleep, "5.7h asleep"), card(.weight, "80 kg"),
      card(.movement, "7,399"), card(.exerciseMinutes, "38 min"),
    ]
    let glance = TodayGlance(cards: cards, day: "2026-10-18")
    XCTAssertEqual(glance.items.map(\.key), ["movement", "hrv", "exerciseMinutes"], "sleep gives way to the strip")
    XCTAssertEqual(glance.items.map(\.value), ["7,399", "65 ms", "38m"])
  }

  func testANumberHealthHasNotGotReadsADash() {
    let glance = TodayGlance(cards: [card(.sleep, MirrorText.none)], day: "2026-10-18")
    XCTAssertEqual(glance.items.map(\.value), Array(repeating: MirrorText.none, count: 3))
  }

  func testOnlyTodaysNumbersAreDrawnAndTheyRoundTrip() throws {
    let glance = TodayGlance(cards: [card(.sleep, "7h asleep")], day: "2026-10-18")
    XCTAssertTrue(glance.isToday("2026-10-18"))
    XCTAssertFalse(glance.isToday("2026-10-19"), "after midnight the line goes")
    XCTAssertEqual(TodayGlance.decode(glance.encoded()), glance)
    XCTAssertNil(TodayGlance.decode(nil))
    XCTAssertNil(TodayGlance.decode(Data("not json".utf8)))
  }

  /// Spec "Today's numbers": what Health gave, through the Today card itself, reads as the spec's example line.
  func testHealthThroughTheTodayCardReadsTheSpecsLine() {
    var h = HealthData()
    h.sleepHours = 5.7
    h.steps = 7399
    h.hrv = 65.2
    h.exerciseMinutes = 38
    let now = la.localTime(year: 2026, month: 10, day: 18, hour: 9)
    let glance = TodayGlance(cards: MirrorText.cards(h, weekly: [:], now: now, clock: la), day: "2026-10-18")
    XCTAssertEqual(
      glance.items.map(\.value).joined(separator: " \u{00B7} "), "7,399 \u{00B7} 65 ms \u{00B7} 38m")

    var none = HealthData()
    none.exerciseMinutes = 0
    let empty = TodayGlance(cards: MirrorText.cards(none, weekly: [:], now: now, clock: la), day: "2026-10-18")
    XCTAssertEqual(
      empty.items.map(\.value), Array(repeating: MirrorText.none, count: 3), "0 minutes reads the card's dash")
  }

  func testStripMarksCountsAndRoundTrip() {
    let glance = TodayGlance(
      day: "2026-10-19", values: [.meditation: 0, .journal: 1, .balloons: 3, .magic: 2, .gym: 1],
      meditationDone: true)
    XCTAssertEqual(glance.items.map(\.key), ["meditation", "journal", "balloons", "magic"])
    XCTAssertEqual(glance.items.map(\.value), ["✓", "✓", "3", "2"], "automatic meditation matches the strip")
    XCTAssertEqual(TodayGlance.decode(glance.encoded()), glance)
    let empty = TodayGlance(day: "2026-10-19", values: [:], meditationDone: false)
    XCTAssertEqual(empty.items.map(\.value), ["○", "○", "0", "0"])
  }

  func testADoneOrCountedStripItemIsLitAndHealthNeverIs() {
    let glance = TodayGlance(
      day: "2026-10-19", values: [.journal: 0, .balloons: 1, .magic: 0], meditationDone: true)
    XCTAssertEqual(glance.items.map(\.isLit), [true, false, true, false], "meditation and a balloon, as on home")
    XCTAssertFalse(TodayGlance.Item(key: "hrv", value: "65 ms").isLit)
    XCTAssertFalse(TodayGlance.Item(key: "movement", value: "5421").isLit, "a Health number is not a strip count")
  }

  func testStripEditsAndPeerCountsUseTheDisplayedTotals() throws {
    let strip = try DailyStrip(db: SQLiteDatabase(path: ":memory:"))
    let day = "2026-10-19"
    func glance() throws -> TodayGlance {
      var values: [DailyItem: Int] = [:]
      for item in DailyItem.allCases { values[item] = try strip.value(item, day: day) }
      return TodayGlance(day: day, values: values, meditationDone: (values[.meditation] ?? 0) > 0)
    }
    try strip.set(.balloons, day: day, value: 1)
    try strip.set(.journal, day: day, value: 1)
    let tapped = try glance()
    XCTAssertEqual(tapped.items.map(\.value), ["○", "✓", "1", "0"])
    try strip.set(.magic, day: day, value: 4)
    try strip.set(.magic, day: "2026-10-18", value: 99)
    try strip.mergePeer(
      "ipad", month: "2026-10",
      rows: [
        StripRow(day: day, item: .balloons, value: 2, updatedAt: 100),
        StripRow(day: day, item: .meditation, value: 1, updatedAt: 100),
      ])
    XCTAssertEqual(try glance().items.map(\.value), ["✓", "✓", "3", "4"])
    XCTAssertNotEqual(try glance(), tapped, "week edits and peer arrivals change the published value")
    XCTAssertEqual(try glance(), try glance(), "unchanged refreshes can skip reloads")
    try strip.set(.journal, day: day, value: 0)
    try strip.set(.magic, day: day, value: 0)
    try strip.mergePeer(
      "ipad", month: "2026-10",
      rows: [
        StripRow(day: day, item: .balloons, value: 0, updatedAt: 200),
        StripRow(day: day, item: .meditation, value: 0, updatedAt: 200),
      ])
    XCTAssertEqual(try glance().items.map(\.value), ["○", "○", "1", "0"], "unchecking and decreasing reach the tile")
  }

  func testStripAndHealthExpireIndependentlyAndOldSleepIsDropped() {
    let health = TodayGlance(cards: [card(.sleep, "7h asleep"), card(.movement, "123")], day: "2026-10-18")
    let strip = TodayGlance(day: "2026-10-19", values: [.magic: 2], meditationDone: false)
    XCTAssertTrue(strip.isToday("2026-10-19"))
    XCTAssertFalse(health.isToday("2026-10-19"), "a new strip never revives yesterday's steps")
    XCTAssertFalse(strip.isToday("2026-10-20"))
    let legacy = TodayGlance.decode(
      Data(
        #"{"day":"2026-10-19","items":[{"key":"sleep","value":"7h"},{"key":"movement","value":"123"}]}"#.utf8))
    XCTAssertEqual(legacy?.healthItems.map(\.key), ["movement"])
  }

  /// Local day, not UTC: 11:30pm in Los Angeles is already tomorrow in UTC, and is still today on the tile.
  func testTheDayIsTheLocalDay() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    let late = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-19T06:30:00Z"))
    XCTAssertEqual(AccessoryLog.dateKey(late, calendar: cal), "2026-10-18")
    let afterMidnight = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-19T07:00:30Z"))
    let glance = TodayGlance(day: AccessoryLog.dateKey(late, calendar: cal), items: [])
    XCTAssertFalse(glance.isToday(AccessoryLog.dateKey(afterMidnight, calendar: cal)), "gone on the stroke")
  }
}
