//  Story 200: the Cockpit page's ☎ opens Grabber Native's own Call screen, with one call, not Context Grabber.

import XCTest

final class CockpitCallUITests: XCTestCase {
  func testPageCallButtonStaysInTheApp() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_COCKPIT"] = "open"
    app.launchEnvironment["GRABBER_COCKPIT_URL"] = "cockpit-bridge-test"
    app.launch()
    let phone = app.webViews.buttons["☎ Call"]
    XCTAssertTrue(phone.appears(within: 20), app.debugDescription)
    phone.tap()
    XCTAssertTrue(app.staticTexts["call-status"].appears(within: 10), app.debugDescription)
    XCTAssertEqual(app.state, .runningForeground)
    // The call dials forTests()' bridge, which never answers (context-grabber-0mn). Hung up while it still rings, it
    // ends cleanly and files no automatic report.
    let hangUp = app.buttons["Hang up"]
    XCTAssertTrue(hangUp.appears(within: 5), app.debugDescription)
    hangUp.tap()
    XCTAssertTrue(app.buttons["call-larry"].appears(within: 5), app.debugDescription)
  }
}
