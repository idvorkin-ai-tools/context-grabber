//  Story 307 (#589) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): a swipe
//  archives a thread with Undo, and the thread's ⋯ menu archives it and goes back to the list.

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

  func testASwipeArchivesAndUndoBringsItBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let undo = app.buttons["chat-archive-undo"]
    XCTAssertTrue(undo.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-thread-\(key)"].isHittable, "folded under Done")
    undo.tap()
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].isHittable, "back in the live list")
  }

  func testTheThreadsMenuArchivesAndGoesBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].tap()
    let more = app.buttons["chat-thread-more"]
    XCTAssertTrue(more.waitForExistence(timeout: 10), app.debugDescription)
    more.tap()
    app.buttons["Archive chat"].tap()
    let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Done (")).firstMatch
    XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
    done.tap()
    app.buttons["chat-thread-\(key)"].tap()
    XCTAssertTrue(more.waitForExistence(timeout: 10), app.debugDescription)
    more.tap()
    XCTAssertTrue(app.buttons["Unarchive chat"].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons["Unarchive chat"].tap()
  }
}
