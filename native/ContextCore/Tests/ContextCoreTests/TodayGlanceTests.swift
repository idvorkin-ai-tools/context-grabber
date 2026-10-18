//  #396, story 226: the Today card's four numbers on the usage tile.

import XCTest

@testable import ContextCore

final class TodayGlanceTests: XCTestCase {
  private func card(_ key: MetricKey, _ value: String) -> MetricCard {
    MetricCard(key: key, label: key.rawValue, value: value, sublabel: "", color: "#000000", boxPlots: [])
  }

  func testTheCardsFourNumbersInItsOrderCutShort() {
    let cards = [
      card(.hrv, "65.2 ms"), card(.sleep, "5.7h asleep"), card(.weight, "80 kg"),
      card(.movement, "7,399"), card(.exerciseMinutes, "38 min"),
    ]
    let glance = TodayGlance(cards: cards, day: "2026-10-18")
    XCTAssertEqual(glance.items.map(\.key), ["sleep", "movement", "hrv", "exerciseMinutes"], "the card's order")
    XCTAssertEqual(glance.items.map(\.value), ["5.7h", "7,399", "65 ms", "38m"])
  }

  func testANumberHealthHasNotGotReadsADash() {
    let glance = TodayGlance(cards: [card(.sleep, MirrorText.none)], day: "2026-10-18")
    XCTAssertEqual(glance.items.map(\.value), Array(repeating: MirrorText.none, count: 4))
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
      glance.items.map(\.value).joined(separator: " \u{00B7} "), "5.7h \u{00B7} 7,399 \u{00B7} 65 ms \u{00B7} 38m")

    var none = HealthData()
    none.exerciseMinutes = 0
    let empty = TodayGlance(cards: MirrorText.cards(none, weekly: [:], now: now, clock: la), day: "2026-10-18")
    XCTAssertEqual(
      empty.items.map(\.value), Array(repeating: MirrorText.none, count: 4), "0 minutes reads the card's dash")
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
