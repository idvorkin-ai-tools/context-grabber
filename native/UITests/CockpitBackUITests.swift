//  #234: a page the Cockpit opens in place can be backed out of: Back takes one real step, Cockpit goes straight to the
//  start page from two deep, Done leaves. Which buttons show when, and that the panel never outlives a failed page,
//  are CockpitPageStateTests on the host; this keeps only what needs WebKit's own back list.
//  Story 200: the page's ☎ opens Grabber Native's own Call screen, with one call, not Context Grabber. It was a class
//  of its own; it shares this launch now (story 757, #905), opened again from the home screen after Done.

import XCTest

final class CockpitBackUITests: XCTestCase {
  func testBackAndCockpitLeaveAPageTheDashboardOpenedAndItsCallStaysInTheApp() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_COCKPIT_URL"] = "cockpit-bridge-test"
    app.launch()
    let row = app.buttons["home-cockpit"]
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    row.tap()

    let away = app.links["Open another page"]
    XCTAssertTrue(away.appears(within: 15), app.debugDescription)
    away.tap()
    let back = app.buttons["cockpit-back"]
    XCTAssertTrue(back.appears(within: 10), app.debugDescription)

    back.tap()
    XCTAssertTrue(away.appears(within: 10), "Back returns to the dashboard")

    // Two pages deep, then Cockpit: the start page in one tap.
    away.tap()
    let deeper = app.links["One page deeper"]
    XCTAssertTrue(deeper.appears(within: 10))
    deeper.tap()
    sleep(1)
    app.buttons["cockpit-home"].tap()
    XCTAssertTrue(away.appears(within: 10), "Cockpit returns to the start page")

    app.buttons["cockpit-done"].tap()
    XCTAssertTrue(row.appears(within: 5), "Done leaves the Cockpit")

    // Story 200: the page's ☎ opens the app's own Call screen, and the app stays in front.
    row.tap()
    let phone = app.webViews.buttons["☎ Call"]
    XCTAssertTrue(phone.appears(within: 20), app.debugDescription)
    phone.tap()
    XCTAssertTrue(app.staticTexts["call-status"].appears(within: 10), app.debugDescription)
    XCTAssertEqual(app.state, .runningForeground)
  }
}
