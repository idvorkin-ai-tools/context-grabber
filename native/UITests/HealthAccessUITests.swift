//  The simulator's one HealthKit check (docs/TESTING.md): launch with GRABBER_MIRROR=healthkit, grant Health's
//  access sheet (simctl cannot tap it), and wait for the app to save the fixture week, grab it back and export.
//  sim-smoke.sh then compares the exports with the TypeScript app's on the same fixture.

import XCTest

final class HealthAccessUITests: XCTestCase {
  func testGrantHealthAccessAndGrabTheFixtureWeek() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_MIRROR"] = "healthkit"
    app.launch()
    let done = app.staticTexts["hook-done"]
    HealthSheet.allow(in: app) { done.exists }
    XCTAssertTrue(done.waitForExistence(timeout: 180), app.debugDescription)
  }
}
