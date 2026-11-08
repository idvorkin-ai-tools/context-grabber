//  Story 183 (#148): upright, a tap on the time pauses and resumes the workout, as it does on its side.
//  Story 188 (#791): a workout survives leaving the timer, and the timer comes back in the mode it was left in.

import XCTest

final class GymTimerUITests: XCTestCase {
  func testTapTheTimeUprightPausesAndResumes() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_TIMER"] = "30,10,3"
    app.launchEnvironment["GRABBER_TURN"] = "upright"
    app.launch()
    let face = app.descendants(matching: .any).matching(identifier: "timer-face").firstMatch
    XCTAssertTrue(face.appears(within: 15), app.debugDescription)
    XCTAssertTrue(app.buttons["STOP"].appears(within: 10), "the hook starts the workout")
    face.tap()
    XCTAssertTrue(app.buttons["RESUME"].appears(within: 5), "a tap on the time pauses")
    face.tap()
    XCTAssertTrue(app.buttons["STOP"].appears(within: 5), "a second tap resumes")
  }

  func testAWorkoutSurvivesLeavingTheTimer() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_TIMER"] = "30,10,3"
    app.launchEnvironment["GRABBER_TURN"] = "upright"
    app.launch()
    XCTAssertTrue(app.buttons["STOP"].appears(within: 15), "the hook starts the rounds")
    // The stopwatch running too, beside the rounds.
    app.buttons["STOPWATCH"].tap()
    XCTAssertTrue(app.buttons["LAP"].appears(within: 5), app.debugDescription)
    app.buttons["START"].tap()
    XCTAssertTrue(app.buttons["STOP"].appears(within: 5), "the stopwatch runs")

    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["home-call"].appears(within: 10), "Done goes home")
    XCTAssertFalse(app.buttons["LAP"].exists)

    // Back, as the card's tap does: the timer's link, nothing started.
    XCUIDevice.shared.system.open(URL(string: "grabbernative://timer")!)
    let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
    if open.appears(within: 5) { open.tap() }
    XCTAssertTrue(app.buttons["LAP"].appears(within: 10), "back in the stopwatch: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["STOP"].exists, "the stopwatch still runs")
    app.buttons["ROUNDS"].tap()
    XCTAssertTrue(app.buttons["STOP"].appears(within: 5), "the rounds still run")
    XCTAssertFalse(app.buttons["START"].exists, "not a fresh timer")
  }
}
