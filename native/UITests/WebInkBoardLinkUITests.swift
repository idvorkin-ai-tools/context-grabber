//  Story 569 (#1354): a link to a board of the Cockpit's web ink page opens that page in Safari, not a problem saying
//  the board isn't on this device.

import XCTest

final class WebInkBoardLinkUITests: XCTestCase {
  func testAWebInkBoardsLinkOpensItsPageInSafari() {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://whiteboard?board=ink-wasn-t"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "the web board opens in Safari")
    app.activate()
    XCTAssertFalse(app.buttons["copy-error"].appears(within: 3), "no board-missing problem: \(app.debugDescription)")
  }
}
