//  Story 820 (context-grabber-9yo) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it):
//  holding one of Igor's own messages and tapping *Send to new chat* moves it to a chat of its own, which opens; the old
//  chat keeps *Moved to a new chat*, which opens the new one. Larry's messages never offer it. Thread igor2-88g.820 is
//  this test's alone: the move changes it for the rest of the fake Cockpit's life.

import XCTest

final class ChatMoveUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private let mine = "Start a fresh plan for the garden"
  private let larrys = "Happy to, in its own chat."

  private func element(_ app: XCUIApplication, _ format: String, _ words: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: format, words)).firstMatch
  }

  private func launch(_ cockpit: String) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.820"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    return app
  }

  func testSendingMyMessageToANewChatMovesItAndLeavesALink() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    var app = launch(cockpit)

    // Larry's message offers no such choice; Copy closes the menu and changes nothing.
    let his = element(app, "label BEGINSWITH %@", larrys)
    XCTAssertTrue(his.appears(within: 20), app.debugDescription)
    his.press(forDuration: 1.2)
    let copy = app.buttons["Copy"].firstMatch
    XCTAssertTrue(copy.appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Send to new chat"].firstMatch.exists, "Larry's message never moves")
    copy.tap()

    // Mine offers it; the new chat opens over this one and Larry answers there.
    let message = element(app, "label BEGINSWITH %@", mine)
    XCTAssertTrue(message.appears(within: 5), app.debugDescription)
    message.press(forDuration: 1.2)
    let send = app.buttons["Send to new chat"].firstMatch
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    send.tap()
    XCTAssertTrue(
      element(app, "label CONTAINS %@", "Larry heard: \(mine)").appears(within: 20), app.debugDescription)

    // The old chat, opened afresh: the message is gone, the moved line is there and opens the new chat.
    app.terminate()
    app = launch(cockpit)
    let moved = app.buttons["chat-moved"].firstMatch
    XCTAssertTrue(moved.appears(within: 20), app.debugDescription)
    XCTAssertTrue(element(app, "label BEGINSWITH %@", larrys).exists, "Larry's reply stays where it was")
    XCTAssertFalse(element(app, "label BEGINSWITH %@", mine).exists, "my message left this chat")
    moved.tap()
    XCTAssertTrue(
      element(app, "label CONTAINS %@", "Larry heard: \(mine)").appears(within: 20), app.debugDescription)
  }
}
