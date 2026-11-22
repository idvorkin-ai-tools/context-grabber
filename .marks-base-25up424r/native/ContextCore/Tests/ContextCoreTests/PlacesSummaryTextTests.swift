//  Story 022: the export's `places` text (port of lib/clustering_v2.ts buildSummaryWeekly / buildSummaryRecent).

import XCTest

@testable import ContextCore

final class PlacesSummaryTextTests: XCTestCase {
  private let cal = la.calendar
  private func t(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Double {
    la.localTime(year: 2026, month: 3, day: day, hour: hour, minute: minute)
  }
  private func stay(_ place: String, _ start: Double, _ end: Double) -> Stay {
    Stay(
      placeId: place, centroid: Coordinate(latitude: 47.6, longitude: -122.3), startTime: start, endTime: end,
      durationMinutes: Int((end - start) / 60_000), pointCount: 10)
  }

  /// Sunday 2026-03-15 starts this week; last week began Sunday 2026-03-08, the day daylight saving began.
  private var stays: [Stay] {
    [
      stay("Home", t(8, 22), t(9, 7)),
      stay("Office", t(10, 9), t(10, 17)),
      stay("Home", t(16, 22), t(17, 7)),
      stay("Office", t(17, 9), t(17, 17)),
      stay("Gym", t(17, 18), t(17, 18, 45)),
      stay("Home", t(17, 22), t(18, 7)),
    ]
  }
  private var now: Double { t(18, 12) }

  func testWeeklyIsHoursPerPlacePerWeekNewestFirst() {
    XCTAssertEqual(
      PlacesSummaryText.weekly(stays, now: now, calendar: cal),
      "This week: Home 18h, Office 8h, Gym 0.8h\nLast week: Home 9h, Office 8h")
  }

  /// A week with no stays does not move the labels: last week stays "Last week" when this week has nothing yet.
  func testAnEmptyWeekKeepsTheOthersLabels() {
    let lastWeekOnly = Array(stays.prefix(2))
    XCTAssertEqual(
      PlacesSummaryText.weekly(lastWeekOnly, now: now, calendar: cal), "Last week: Home 9h, Office 8h")
    XCTAssertEqual(
      PlacesSummaryText.weekly([stay("Home", t(1, 22), t(2, 6))], now: now, calendar: cal), "2 weeks ago: Home 8h")
  }

  func testRecentIsTheLastThreeDaysAsNamedStaysWithLongTransits() {
    let transit = [
      TransitSegment(
        startTime: t(17, 7), endTime: t(17, 9), durationMinutes: 120, distanceKm: 14.3, fromPlaceId: "Home",
        toPlaceId: "Office"),
      TransitSegment(
        startTime: t(17, 17, 10), endTime: t(17, 17, 40), durationMinutes: 30, distanceKm: 2, fromPlaceId: "Office",
        toPlaceId: "Gym"),
    ]
    XCTAssertEqual(
      PlacesSummaryText.recent(stays, transit: transit, now: now, calendar: cal),
      "Mon Mar 16: Home Mon Mar 16 10pm\u{2013}Tue Mar 17 7am (9h)\n"
        + "Tue Mar 17: [2h/14.3km], Office Tue Mar 17 9am\u{2013}5pm (8h), Gym Tue Mar 17 6pm\u{2013}6:45pm (45min), "
        + "Home Tue Mar 17 10pm\u{2013}Wed Mar 18 7am (9h)")
  }

  func testNoStaysIsNoSection() {
    XCTAssertNil(PlacesSummaryText.summary(StayClusters(stays: [], transit: []), now: now, calendar: cal))
    let s = PlacesSummaryText.summary(StayClusters(stays: stays, transit: []), now: now, calendar: cal)
    XCTAssertEqual(s?.weekly.hasPrefix("This week: Home 18h"), true)
    XCTAssertEqual(s?.recent.hasPrefix("Mon Mar 16: Home"), true)
  }

  func testTheTrailStartsAtLastWeeksSunday() {
    XCTAssertEqual(PlacesSummaryText.since(now: now, calendar: cal), t(8, 0))
    XCTAssertEqual(PlacesSummaryText.since(now: t(15, 0, 5), calendar: cal), t(8, 0), "on Sunday itself")
    XCTAssertEqual(PlacesSummaryText.readFrom(now: now, calendar: cal), t(7, 0), "a day earlier")
  }

  /// A Saturday night at home into the Sunday that starts last week counts whole in the week it began in (two
  /// weeks ago, not shown), as the React Native app attributed it, not as a Sunday-morning stay of last week.
  func testASaturdayNightIntoTheWindowCountsInTheWeekItBegan() {
    func at(_ place: Coordinate, from: Double, to: Double) -> [LocationPoint] {
      stride(from: from, through: to, by: 5 * 60_000).map {
        LocationPoint(latitude: place.latitude, longitude: place.longitude, accuracy: 5, timestamp: $0)
      }
    }
    let home = Coordinate(latitude: 47.6, longitude: -122.3)
    let office = Coordinate(latitude: 47.65, longitude: -122.35)
    let trail =
      at(home, from: t(7, 22), to: t(8, 8)) + at(office, from: t(10, 9), to: t(10, 17))
      + at(home, from: t(16, 22), to: t(17, 7))
    let known = [
      KnownPlace(id: 1, name: "Home", latitude: home.latitude, longitude: home.longitude, radiusMeters: 100),
      KnownPlace(id: 2, name: "Office", latitude: office.latitude, longitude: office.longitude, radiusMeters: 100),
    ]
    func weekly(readingFrom start: Double) -> String? {
      let clusters = StayClustering.cluster(trail.filter { $0.timestamp >= start }, knownPlaces: known)
      return PlacesSummaryText.summary(clusters, now: now, calendar: cal)?.weekly
    }
    let expected = "This week: Home 9h\nLast week: Office 8h"
    XCTAssertEqual(weekly(readingFrom: PlacesSummaryText.readFrom(now: now, calendar: cal)), expected)
    XCTAssertEqual(weekly(readingFrom: 0), expected, "the whole trail says the same")
    XCTAssertEqual(
      weekly(readingFrom: PlacesSummaryText.since(now: now, calendar: cal))?.contains("Last week: Office 8h, Home"),
      true, "cut at Sunday midnight, the night's tail would land in last week")
  }
}
