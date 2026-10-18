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
}
