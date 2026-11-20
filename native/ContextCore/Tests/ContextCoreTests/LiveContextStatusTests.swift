//  Story 338: the line under *Tell Larry when I arrive and leave* says the last thing sent, or why nothing is.

import XCTest

@testable import ContextCore

private let pacific = TimeZone(identifier: "America/Los_Angeles") ?? .current
/// Monday 16 March 2026, 05:47:00 Pacific.
private let monday = 1_773_665_220_000.0

final class LiveContextStatusTests: XCTestCase {
  private let arrived = LiveContextEvent(
    kind: .arrived, placeId: 13, place: "Kettlebility", at: monday, detectedAt: monday + 300_000)

  func testTheLastThingSent() {
    XCTAssertEqual(
      LiveContextStatus.line(
        on: true, recording: true, knownPlaces: 4, lastSent: arrived, waiting: 0, timeZone: pacific),
      "Arrived at Kettlebility · Mon 5:47")
  }

  func testWaitingIsCounted() {
    let left = LiveContextEvent(kind: .left, placeId: 13, place: "Kettlebility", at: monday, detectedAt: monday)
    XCTAssertEqual(
      LiveContextStatus.line(on: true, recording: true, knownPlaces: 4, lastSent: left, waiting: 2, timeZone: pacific),
      "Left Kettlebility · Mon 5:47 · 2 waiting for the Cockpit")
    XCTAssertEqual(
      LiveContextStatus.line(on: true, recording: true, knownPlaces: 4, lastSent: nil, waiting: 1, timeZone: pacific),
      "Nothing sent yet · 1 waiting for the Cockpit")
  }

  func testTrackingOffStillCountsWhatWaits() {
    XCTAssertEqual(
      LiveContextStatus.line(on: true, recording: false, knownPlaces: 4, lastSent: arrived, waiting: 2),
      "Background tracking is off, so nothing new is noticed · 2 waiting for the Cockpit")
  }

  func testWhyNothingIsSent() {
    XCTAssertEqual(
      LiveContextStatus.line(on: false, recording: true, knownPlaces: 4, lastSent: arrived, waiting: 0),
      "Off: Larry hears nothing about where you go.")
    XCTAssertEqual(
      LiveContextStatus.line(on: true, recording: false, knownPlaces: 4, lastSent: arrived, waiting: 0),
      "Background tracking is off, so nothing new is noticed")
    XCTAssertEqual(
      LiveContextStatus.line(on: true, recording: true, knownPlaces: 0, lastSent: nil, waiting: 0),
      "Nothing is sent until a place is named.")
  }
}
