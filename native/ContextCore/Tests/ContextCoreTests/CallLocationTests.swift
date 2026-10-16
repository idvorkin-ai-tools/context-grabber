//  #107, story 092: the fix a call sends, named for its known place, and which later fixes are worth a frame.

import ContextCore
import XCTest

final class CallLocationTests: XCTestCase {
  let home = KnownPlace(id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100)

  func testAFixIsNamedForItsKnownPlace() {
    let at = Date(timeIntervalSince1970: 1_760_000_000)
    let inside = CallLocation.fix(lat: 47.60625, lon: -122.33215, accuracy: 12.4, at: at, knownPlaces: [home])
    XCTAssertEqual(inside.place, "Home")
    XCTAssertEqual(inside.accuracyM, 12)
    XCTAssertEqual(inside.at, "2025-10-09T08:53:20.000Z")
    let away = CallLocation.fix(lat: 47.62, lon: -122.33, accuracy: -1, at: at, knownPlaces: [home])
    XCTAssertNil(away.place)
    XCTAssertNil(away.accuracyM, "iOS's negative accuracy means none")
  }

  func testOnlyASignificantMoveIsWorthAFrame() {
    let at = Date(timeIntervalSince1970: 1_760_000_000)
    let start = CallLocation.fix(lat: 47.6062, lon: -122.3321, accuracy: 10, at: at, knownPlaces: [home])
    let fidget = CallLocation.fix(lat: 47.6063, lon: -122.3322, accuracy: 10, at: at, knownPlaces: [home])
    let leftHome = CallLocation.fix(lat: 47.6075, lon: -122.3321, accuracy: 10, at: at, knownPlaces: [home])  // ~145 m
    let far = CallLocation.fix(lat: 47.6100, lon: -122.3321, accuracy: 10, at: at, knownPlaces: [])  // ~420 m
    XCTAssertTrue(CallLocation.isSignificantMove(from: nil, to: start), "the first fix always goes")
    XCTAssertFalse(CallLocation.isSignificantMove(from: start, to: fidget), "standing still sends none")
    XCTAssertTrue(CallLocation.isSignificantMove(from: start, to: leftHome), "a different place, under 200 m")
    XCTAssertFalse(CallLocation.isSignificantMove(from: leftHome, to: leftHome))
    XCTAssertTrue(CallLocation.isSignificantMove(from: leftHome, to: far), "200 m or more")
  }
}
