//  Story 338 (#84): *Tell Larry when I arrive and leave* in Places' Tracking section turns off and on, and the line
//  under it says so. The simulator has no trail or Cockpit to send to, so this sees only the switch and its line.

import XCTest

final class LiveContextSwitchUITests: XCTestCase {
  func testTheSwitchTurnsOffAndSaysSo() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_PLACES"] = "open"
    app.launch()
    let toggle = app.switches["live-context-switch"].firstMatch
    let status = app.staticTexts["live-context-status"]
    // The line sits under the switch: scroll until both are on screen, or the line is not in the tree yet.
    for _ in 0..<15 where !(toggle.exists && toggle.isHittable && status.exists && status.isHittable) { app.swipeUp() }
    XCTAssertTrue(toggle.appears(within: 10), app.debugDescription)
    XCTAssertTrue(status.appears(within: 5), app.debugDescription)
    if (toggle.value as? String) == "0" {
      toggle.switches.firstMatch.tap()
    }
    XCTAssertEqual(toggle.value as? String, "1")
    toggle.switches.firstMatch.tap()
    XCTAssertEqual(status.label, "Off: Larry hears nothing about where you go.")
    XCTAssertEqual(toggle.value as? String, "0")
    // Back on, as the simulator found it: the default.
    toggle.switches.firstMatch.tap()
    XCTAssertEqual(toggle.value as? String, "1")
    XCTAssertNotEqual(status.label, "Off: Larry hears nothing about where you go.")
  }
}
