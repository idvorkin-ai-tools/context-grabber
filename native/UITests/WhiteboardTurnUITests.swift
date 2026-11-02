//  Stories 344 and 349 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a
//  stroke and a pause bring Claude's ghost, Larry's turn brings his line and his marks. Keeping a ghost is a finger
//  tap, and on the simulator a finger draws, so keeping is the iPad's check.

import XCTest

final class WhiteboardTurnUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.waitForExistence(timeout: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    // The canvas is not in the accessibility snapshot: the stroke goes to the window by position.
    sleep(1)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let showing = { (n: Int) in NSPredicate(format: "label == %@", "Ghosts on, \(n) showing") }
    expectation(for: showing(1), evaluatedWith: ghosts)
    waitForExpectations(timeout: 8)

    app.buttons["whiteboard-larry"].tap()
    expectation(for: showing(2), evaluatedWith: ghosts)
    waitForExpectations(timeout: 15)
  }
}
