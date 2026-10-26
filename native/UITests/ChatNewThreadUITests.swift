//  Stories 262–264 (#536) on the simulator: Chat's + opens a new, empty thread with the ordinary bar (the field,
//  Paste image, the mic), not the old New chat sheet. Sending from it is a phone check (the simulator's Cockpit is a
//  closed port here), as are dictation and pasting.

import XCTest

final class ChatNewThreadUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testThePlusOpensANewThreadWithTheOrdinaryBar() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    XCTAssertTrue(plus.waitForExistence(timeout: 20), app.debugDescription)
    plus.tap()
    XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout: 5), app.debugDescription)
    // The thread's identifier covers its children, so the bar is found by labels.
    let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message Larry")).firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5), "the ordinary bar's field: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["Paste image"].exists, "Paste image is on the bar")
    XCTAssertTrue(app.buttons["Speak a message"].exists, "the chat mic is on the bar")
    XCTAssertFalse(app.buttons["Send"].isEnabled, "nothing to send yet")
    XCTAssertFalse(app.buttons["Send and start another"].exists, "no sheet")
    XCTAssertFalse(app.buttons["Cancel"].exists, "no sheet")

    // Back with nothing sent leaves no thread behind.
    app.navigationBars["New chat"].buttons.firstMatch.tap()
    XCTAssertTrue(plus.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.descendants(matching: .any)["chat-pending-waiting"].exists, "no new thread waits to go")
  }
}
