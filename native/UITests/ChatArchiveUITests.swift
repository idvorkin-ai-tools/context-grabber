//  Stories 307-309 (#589) and 311-314 (#599) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh
//  starts it): a swipe archives a thread with Undo, the thread's ⋯ menu archives it and goes back to the list, both ways
//  of Unarchive bring it back to the live list, Select archives several with one Undo and Cancel archives none, and
//  Review ticks what looks done. Each test leaves the thread live: the fake Cockpit outlives a test.

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
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
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

  /// The Done fold, or a row just opened under it, can be below the buttons' bar, where a tap lands on the bar: scrolled
  /// up clear of it, as he would. A swipe's Undo line pushes the whole list down for five seconds as well.
  private func scrollClearOfTheBar(_ row: XCUIElement, _ app: XCUIApplication) {
    let bar = app.otherElements["chat-new-bar"]
    let origin = app.coordinate(withNormalizedOffset: .zero)
    for _ in 0..<6 where row.frame.maxY > bar.frame.minY {
      origin.withOffset(CGVector(dx: 30, dy: 450))
        .press(
          forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 30, dy: 300)), withVelocity: .slow,
          thenHoldForDuration: 0.3)
    }
    XCTAssertLessThanOrEqual(row.frame.maxY, bar.frame.minY, "scrolled clear: \(app.debugDescription)")
  }

  /// Story 506 (#685): the + and the voice button float over the list, which runs to the foot of the screen, with no bar
  /// across it.
  func testTheNewChatButtonsFloatOverTheList() throws {
    let app = try openList()
    let bar = app.otherElements["chat-new-bar"]
    XCTAssertTrue(bar.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(bar.frame.width, app.windows.firstMatch.frame.width / 2, "only the buttons, not a bar")
    let list = app.collectionViews.firstMatch
    XCTAssertGreaterThanOrEqual(list.frame.maxY, app.buttons["inbox-add"].frame.maxY, "the list runs beneath them")
  }

  func testASwipeArchivesAndUndoBringsItBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let undo = app.buttons["chat-archive-undo"]
    XCTAssertTrue(undo.appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-thread-\(key)"].isHittable, "folded under Done")
    undo.tap()
    assertBackInTheLiveList(app)
  }

  func testASwipeUnderDoneUnarchives() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let done = doneFold(app)
    XCTAssertTrue(done.appears(within: 5), app.debugDescription)
    scrollClearOfTheBar(done, app)
    done.tap()
    let row = app.buttons["chat-thread-\(key)"]
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)
    scrollClearOfTheBar(row, app)
    row.swipeLeft()
    app.buttons["Unarchive"].tap()
    assertBackInTheLiveList(app)
  }

  func testTheThreadsMenuArchivesAndGoesBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].tap()
    let more = app.buttons["chat-thread-more"]
    XCTAssertTrue(more.appears(within: 10), app.debugDescription)
    more.tap()
    app.buttons["Archive chat"].tap()
    let done = doneFold(app)
    XCTAssertTrue(done.appears(within: 5), app.debugDescription)
    scrollClearOfTheBar(done, app)
    done.tap()
    scrollClearOfTheBar(app.buttons["chat-thread-\(key)"], app)
    app.buttons["chat-thread-\(key)"].tap()
    XCTAssertTrue(more.appears(within: 10), app.debugDescription)
    more.tap()
    XCTAssertTrue(app.buttons["Unarchive chat"].appears(within: 5), app.debugDescription)
    app.buttons["Unarchive chat"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    assertBackInTheLiveList(app)
  }

  func testReviewTicksWhatLooksDoneAndOneTapArchivesIt() throws {
    let app = try openList()
    let done = "igor2-88g.593"
    XCTAssertTrue(app.staticTexts["Looks done"].appears(within: 5), app.debugDescription)
    app.buttons["chat-review-done"].tap()
    let archive = app.buttons["chat-archive-selected"]
    XCTAssertTrue(archive.appears(within: 5), app.debugDescription)
    XCTAssertEqual(archive.label, "Archive (1)")
    archive.tap()
    let undo = app.buttons["chat-archive-undo"]
    XCTAssertTrue(undo.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.staticTexts["Archived \"Finished plan\""].exists, app.debugDescription)
    undo.tap()
    XCTAssertTrue(app.buttons["chat-review-done"].appears(within: 10), "the proposal is back")
    XCTAssertTrue(app.buttons["chat-thread-\(done)"].isHittable, "back in the live list")
  }

  func testSelectArchivesSeveralTogetherAndCancelArchivesNone() throws {
    let app = try openList()
    let select = app.buttons["chat-select"]
    select.tap()
    let (one, two) = (app.buttons["chat-tick-\(key)"], app.buttons["chat-tick-igor2-88g.593"])
    XCTAssertTrue(one.appears(within: 5), app.debugDescription)
    one.tap()
    two.tap()
    let archive = app.buttons["chat-archive-selected"]
    XCTAssertEqual(archive.label, "Archive (2)")
    let buttons = app.otherElements["chat-new-bar"]
    XCTAssertFalse(archive.frame.intersects(buttons.frame), "Archive clear of the floating buttons")
    select.tap()
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].appears(within: 5), "Cancel leaves the list")
    XCTAssertFalse(doneFold(app).exists, "nothing archived")

    select.tap()
    XCTAssertEqual(archive.label, "Archive (0)")
    XCTAssertFalse(archive.isEnabled)
    one.tap()
    two.tap()
    archive.tap()
    XCTAssertTrue(app.staticTexts["Archived 2 chats"].appears(within: 5), app.debugDescription)
    app.buttons["chat-archive-undo"].tap()
    assertBackInTheLiveList(app)
  }

  func testThePinnedThreadIsOnTopAndCannotBeArchived() throws {
    let app = try openList()
    let pinned = app.buttons["chat-thread-igor2-88g.1268"]
    XCTAssertTrue(pinned.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(pinned.frame.minY, app.buttons["chat-thread-\(key)"].frame.minY, "first in the list")
    XCTAssertTrue(pinned.label.contains("Pinned"), pinned.label)
    XCTAssertTrue(pinned.label.contains("Drop anything here"), pinned.label)
    pinned.swipeLeft()
    XCTAssertFalse(app.buttons["Archive"].appears(within: 2), "no swipe to archive")
    // With nothing to reveal, the simulated swipe lands as a tap and opens the thread.
    if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
    XCTAssertTrue(app.buttons["chat-select"].appears(within: 3), app.debugDescription)
    app.buttons["chat-select"].tap()
    XCTAssertTrue(app.buttons["chat-tick-\(key)"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-tick-igor2-88g.1268"].exists, "not tickable")
    app.buttons["chat-select"].tap()

    pinned.tap()
    XCTAssertTrue(app.textFields.firstMatch.appears(within: 10), "it opens on the bar that writes to it")
    XCTAssertFalse(app.buttons["chat-thread-more"].exists, "no menu to archive it from")
  }
}
