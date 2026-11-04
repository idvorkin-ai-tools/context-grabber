//  Story 441: a metric's detail fills an iPad's window, and stays a sheet on an iPhone.

import XCTest

final class MetricDetailUITests: XCTestCase {
  func testTheDetailFillsAnIPadsWindow() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_MIRROR"] = "fixture"
    app.launchEnvironment["GRABBER_METRIC"] = "sleep"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let close = app.buttons["Close"].firstMatch
    XCTAssertTrue(close.waitForExistence(timeout: 30), app.debugDescription)
    let bar = app.navigationBars.containing(.button, identifier: "Close").firstMatch
    XCTAssertTrue(bar.exists, app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "the detail"
    shot.lifetime = .keepAlways
    add(shot)
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(bar.frame.width, app.windows.firstMatch.frame.width, accuracy: 1, "the whole window's width")
      XCTAssertEqual(bar.frame.minY, 0, accuracy: 60, "from the top of the window")
    }
    close.tap()
    XCTAssertTrue(close.waitForNonExistence(timeout: 5), "the X closes it")
  }
}
