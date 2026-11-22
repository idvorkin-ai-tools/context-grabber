//  Arrivals and departures at known places for Larry (#84, stories 099, 335, 336): five minutes in, five minutes
//  out, passing by sends nothing, silence counts as staying, an imprecise fix is ignored. And on the real trail
//  (__tests__/fixtures/locations.json with its four real known places): the week's arrivals and departures, with
//  the 1.4 km fix one evening at home sending nothing.

import XCTest

@testable import ContextCore

private let minute = 60_000.0
private let gym = KnownPlace(id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100)
private let cafe = KnownPlace(id: 14, name: "Milstead & Co", latitude: 47.6762, longitude: -122.3160, radiusMeters: 50)
private let places = [gym, cafe]
/// About 1 km north of the gym: at no known place.
private let street = Coordinate(latitude: 47.6852, longitude: -122.3187)

private func at(_ place: KnownPlace, _ t: Double, accuracy: Double? = 10) -> LocationPoint {
  LocationPoint(latitude: place.latitude, longitude: place.longitude, accuracy: accuracy, timestamp: t * minute)
}

private func atStreet(_ t: Double) -> LocationPoint {
  LocationPoint(latitude: street.latitude, longitude: street.longitude, accuracy: 10, timestamp: t * minute)
}

private func events(_ changes: [LiveContextDetector.Change]) -> [LiveContextEvent] {
  changes.compactMap { if case .event(let e) = $0 { return e } else { return nil } }
}

/// A detector already settled on the street at minute 0, as after a fresh start away from every known place.
private func onTheStreet() -> LiveContextDetector {
  var d = LiveContextDetector()
  _ = d.observe(atStreet(-10), places: places)
  XCTAssertEqual(d.advance(to: 0), [.started(place: nil, at: -5 * minute)])
  return d
}

final class LiveContextDetectorTests: XCTestCase {
  func testFiveMinutesInsideIsAnArrivalTimedAtTheFirstPositionInside() {
    var d = onTheStreet()
    var got: [LiveContextDetector.Change] = []
    for t in stride(from: 10.0, through: 16, by: 1) { got += d.observe(at(gym, t), places: places) }
    let e = events(got)
    XCTAssertEqual(e.count, 1)
    XCTAssertEqual(e.first?.kind, .arrived)
    XCTAssertEqual(e.first?.place, "Kettlebility")
    XCTAssertEqual(e.first?.at, 10 * minute)
    XCTAssertEqual(e.first?.detectedAt, 15 * minute)
    XCTAssertEqual(e.first?.id, "arrived-13-600000")
  }

  func testSilenceInsideCountsAsStaying() {
    var d = onTheStreet()
    XCTAssertEqual(d.observe(at(gym, 10), places: places), [])
    XCTAssertEqual(d.advance(to: 14.9 * minute), [])
    XCTAssertEqual(events(d.advance(to: 15 * minute)).map(\.kind), [.arrived])
    XCTAssertEqual(d.currentPlace, "Kettlebility")
  }

  func testPassingBySendsNothing() {
    var d = onTheStreet()
    var got: [LiveContextDetector.Change] = []
    for t in stride(from: 10.0, through: 14, by: 1) { got += d.observe(at(gym, t), places: places) }
    for t in stride(from: 14.5, through: 40, by: 0.5) { got += d.observe(atStreet(t), places: places) }
    got += d.advance(to: 120 * minute)
    XCTAssertEqual(got, [])
    XCTAssertNil(d.currentPlace)
  }

  func testFiveMinutesOutsideIsADepartureWithTheDwell() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    _ = d.observe(at(gym, 70), places: places)
    XCTAssertEqual(d.observe(atStreet(71), places: places), [])
    XCTAssertEqual(d.advance(to: 75.9 * minute), [])
    let left = events(d.advance(to: 76 * minute))
    XCTAssertEqual(left.map(\.kind), [.left])
    XCTAssertEqual(left.first?.at, 71 * minute)
    XCTAssertEqual(left.first?.dwellMinutes, 61)
    XCTAssertEqual(left.first?.id, "left-13-4260000")
  }

  func testSteppingOutAndBackSendsNothing() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    _ = d.observe(at(gym, 20), places: places)
    var got = d.observe(atStreet(21), places: places)
    got += d.observe(atStreet(24), places: places)
    got += d.observe(at(gym, 25), places: places)
    got += d.advance(to: 60 * minute)
    XCTAssertEqual(got, [])
    XCTAssertEqual(d.currentPlace, "Kettlebility")
  }

  func testStraightIntoTheNextPlaceIsALeaveThenAnArrival() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    _ = d.observe(at(gym, 20), places: places)
    var got = d.observe(at(cafe, 21), places: places)
    got += d.observe(at(cafe, 27), places: places)
    XCTAssertEqual(events(got).map(\.kind), [.left, .arrived])
    XCTAssertEqual(events(got).map(\.place), ["Kettlebility", "Milstead & Co"])
    XCTAssertEqual(events(got).map(\.at), [21 * minute, 21 * minute])
  }

  func testAnImpreciseFixIsIgnoredAndCounted() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    _ = d.observe(at(gym, 20), places: places)
    // One wild position far away, then silence: no departure.
    let wild = LocationPoint(
      latitude: street.latitude, longitude: street.longitude, accuracy: 1414, timestamp: 21 * minute)
    XCTAssertEqual(d.observe(wild, places: places), [])
    XCTAssertEqual(d.advance(to: 600 * minute), [])
    XCTAssertEqual(d.currentPlace, "Kettlebility")
    XCTAssertEqual(d.takeIgnoredFixes(), 1)
    XCTAssertEqual(d.ignoredFixes, 0)
  }

  func testTheStartingPlaceIsNotSent() {
    var d = LiveContextDetector()
    var got: [LiveContextDetector.Change] = []
    for t in stride(from: 0.0, through: 6, by: 1) { got += d.observe(at(gym, t), places: places) }
    XCTAssertEqual(got, [.started(place: "Kettlebility", at: 5 * minute)])
    // Leaving the starting place is a departure, with no dwell (the arrival was not seen).
    _ = d.observe(atStreet(30), places: places)
    let left = events(d.advance(to: 35 * minute))
    XCTAssertEqual(left.map(\.kind), [.left])
    XCTAssertNil(left.first?.dwellMinutes)
  }

  func testAnOlderPositionIsIgnored() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    XCTAssertEqual(d.observe(atStreet(5), places: places), [])
    XCTAssertEqual(events(d.advance(to: 15 * minute)).map(\.kind), [.arrived])
  }

  func testADeletedPlaceIsLeftUnderItsOldName() {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    _ = d.observe(at(gym, 20), places: places)
    let renamed = [
      KnownPlace(id: 14, name: "Café", latitude: cafe.latitude, longitude: cafe.longitude, radiusMeters: 50)
    ]
    _ = d.observe(at(gym, 21), places: renamed)
    let left = events(d.advance(to: 26 * minute))
    XCTAssertEqual(left.map(\.place), ["Kettlebility"])
  }

  func testTheStateSurvivesBeingKeptBetweenWakes() throws {
    var d = onTheStreet()
    _ = d.observe(at(gym, 10), places: places)
    var kept = try JSONDecoder().decode(LiveContextDetector.self, from: JSONEncoder().encode(d))
    XCTAssertEqual(kept, d)
    XCTAssertEqual(events(kept.advance(to: 15 * minute)).map(\.kind), [.arrived])
  }

  // MARK: The real trail

  private struct Fixture: Decodable {
    let knownPlaces: [KnownPlace]
  }

  func testTheRealWeek() throws {
    let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let repo = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    let points = try JSONDecoder().decode(
      [LocationPoint].self, from: Data(contentsOf: repo.appendingPathComponent("__tests__/fixtures/locations.json")))
    let known = try JSONDecoder().decode(
      Fixture.self, from: Data(contentsOf: here.appendingPathComponent("Fixtures/places-expected.json"))
    ).knownPlaces
    var d = LiveContextDetector()
    var changes: [LiveContextDetector.Change] = []
    for p in points.sorted(by: { $0.timestamp < $1.timestamp }) { changes += d.observe(p, places: known) }
    guard case .started(let start, _) = changes.first else { return XCTFail("no starting point") }
    XCTAssertEqual(start, "Home")
    let all = events(changes)
    XCTAssertEqual(all.count, 74)
    XCTAssertGreaterThan(d.ignoredFixes, 0)

    // Arrivals and departures alternate, and each departure leaves the place last arrived at.
    var at: String? = "Home"
    for e in all {
      switch e.kind {
      case .arrived:
        XCTAssertNil(at, "arrived at \(e.place) while at \(at ?? "")")
        at = e.place
      case .left:
        XCTAssertEqual(at, e.place)
        at = nil
      }
    }
    XCTAssertEqual(Set(all.map(\.id)).count, all.count, "every event has its own id")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    func local(_ ms: Double) -> String {
      let c = calendar.dateComponents([.month, .day, .hour, .minute], from: Geo.date(ms))
      return String(format: "%02d-%02d %02d:%02d", c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
    let lines = all.map { "\(local($0.at)) \($0.kind.rawValue) \($0.place)" }
    // Monday 16 March, as Igor lived it: home, the gym, work, home.
    XCTAssertEqual(
      lines.filter { $0.hasPrefix("03-16") },
      [
        "03-16 05:19 arrived Home", "03-16 05:40 left Home", "03-16 05:47 arrived Kettlebility",
        "03-16 07:10 left Kettlebility", "03-16 07:25 arrived Work", "03-16 16:56 left Work",
        "03-16 17:12 arrived Home",
      ])
    // The 1.4 km fix at 19:19 on Tuesday 24 March sends no departure; the real one is Wednesday morning.
    XCTAssertFalse(lines.contains { $0.hasPrefix("03-24 19") && $0.hasSuffix("left Home") })
    XCTAssertTrue(lines.contains("03-25 07:37 left Home"))
  }
}
