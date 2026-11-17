//  Story 910 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): an arrow drawn
//  from one word to another, selected, offers Connect, and Connect leaves one clean arrow in its place. Where its ends
//  land, how it routes and how it follows are `BoardConnectorsTests` on the host; this checks the button reaches them on
//  paper. The simulator can't draw a lasso, so `GRABBER_WHITEBOARD_SELECT_NEWEST` selects the arrow as one would.

import XCTest

final class WhiteboardConnectUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  func testALassoedArrowBetweenTwoWordsConnectsThem() throws {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD_SELECT_NEWEST"] = "3"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    sleep(1)
    // Two "words", then an arrow from the first's end to the second's start.
    point(app, 0.12, 0.30).press(forDuration: 0.05, thenDragTo: point(app, 0.25, 0.31))
    point(app, 0.60, 0.50).press(forDuration: 0.05, thenDragTo: point(app, 0.75, 0.51))
    let send = app.buttons["whiteboard-send"]
    wait(send, label: "Send to Larry, 2 strokes")
    point(app, 0.26, 0.31).press(forDuration: 0.05, thenDragTo: point(app, 0.59, 0.50))
    wait(send, label: "Send to Larry, 3 strokes")
    let connect = app.buttons["whiteboard-connect"]
    XCTAssertTrue(connect.appears(within: 5), "Connect beside the selected arrow: \(app.debugDescription)")
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "arrow selected, with Connect"
    picture.lifetime = .keepAlways
    add(picture)
    connect.tap()
    // The drawn arrow goes and the connector takes its place: still three strokes, and Connect goes with the selection.
    wait(send, label: "Send to Larry, 3 strokes")
    XCTAssertFalse(connect.waitForExistence(timeout: 2), "Connect goes once it is used")
  }
}
