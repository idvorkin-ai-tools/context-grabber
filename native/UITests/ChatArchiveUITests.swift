//  Stories 307-309 (#589) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): a swipe
//  archives a thread with Undo, the thread's ⋯ menu archives it and goes back to the list, and both ways of Unarchive
//  bring it back to the live list. Each test leaves the thread live: the fake Cockpit outlives a test.

import XCTest

final class ChatArchiveUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private let key = "igor2-88g.592"

  private func openList() throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let row = app.buttons["chat-thread-\(key)"]
    XCTAssertTrue(row.waitForExistence(timeout: 20), app.debugDescription)
    return app
  }

  private func doneFold(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Done (")).firstMatch
  }

  /// With the only archived thread back, the fold is gone and the row is in the live list.
  private func assertBackInTheLiveList(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(doneFold(app).waitForNonExistence(timeout: 10), app.debugDescription, file: file, line: line)
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].isHittable, "back in the live list", file: file, line: line)
  }

  func testASwipeArchivesAndUndoBringsItBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let undo = app.buttons["chat-archive-undo"]
    XCTAssertTrue(undo.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-thread-\(key)"].isHittable, "folded under Done")
    undo.tap()
    assertBackInTheLiveList(app)
  }

  func testASwipeUnderDoneUnarchives() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let done = doneFold(app)
    XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
    done.tap()
    let row = app.buttons["chat-thread-\(key)"]
    XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
    row.swipeLeft()
    app.buttons["Unarchive"].tap()
    assertBackInTheLiveList(app)
  }

  func testTheThreadsMenuArchivesAndGoesBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].tap()
    let more = app.buttons["chat-thread-more"]
    XCTAssertTrue(more.waitForExistence(timeout: 10), app.debugDescription)
    more.tap()
    app.buttons["Archive chat"].tap()
    let done = doneFold(app)
    XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
    done.tap()
    app.buttons["chat-thread-\(key)"].tap()
    XCTAssertTrue(more.waitForExistence(timeout: 10), app.debugDescription)
    more.tap()
    XCTAssertTrue(app.buttons["Unarchive chat"].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons["Unarchive chat"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    assertBackInTheLiveList(app)
  }
}
