//  Story 274 (#449): after a send the bar is empty, with the keyboard still up for the next message.

import XCTest

final class ChatComposeClearsUITests: XCTestCase {
  func testTheBarEmptiesAfterASend() throws {
    let app = XCUIApplication()
    // A Cockpit nobody answers on: the message waits on the phone and nothing reaches Larry.
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    // Codex on #524: what this test sends waits in the simulator's outbox, and a later launch without the dead
    // address would deliver it to the real Cockpit. Delete each one through its bubble, as Igor would.
    addTeardownBlock {
      for text in ["first", "second"] {
        let bubble = app.staticTexts[text].firstMatch
        guard bubble.waitForExistence(timeout: 3) else { continue }
        bubble.press(forDuration: 1.2)
        let delete = app.buttons["Delete"].firstMatch
        if delete.waitForExistence(timeout: 3) { delete.tap() }
        XCTAssertFalse(app.staticTexts[text].waitForExistence(timeout: 2), "\(text) left in the outbox")
      }
    }
    // The thread's identifier covers its children, so the bar is found by its placeholder.
    let byPlaceholder = NSPredicate(format: "placeholderValue == %@ OR value == %@", "Message Larry", "Message Larry")
    let compose = app.descendants(matching: .any).matching(byPlaceholder).firstMatch
    XCTAssertTrue(compose.waitForExistence(timeout: 20), app.debugDescription)
    compose.tap()
    compose.typeText("first")
    app.buttons["Send"].tap()
    // The first send asks for notifications (chat spec); a clean simulator shows the system alert, so answer it
    // and focus the field again. The send under test is the next one, which the alert never interrupts.
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.waitForExistence(timeout: 3) {
      allow.tap()
      compose.tap()
    }

    let field = compose
    let empty = NSPredicate { _, _ in
      ((field.value as? String) ?? "").replacingOccurrences(of: "Message Larry", with: "").isEmpty
    }
    expectation(for: empty, evaluatedWith: field)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard is up before the send under test")
    field.typeText("second")
    app.buttons["Send"].tap()
    expectation(for: empty, evaluatedWith: field)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard stays up for the next message")
    XCTAssertFalse(app.buttons["Send"].isEnabled, "nothing left to send twice")
    // Straight on, with no tap on the field: the next message goes in where the last one was.
    field.typeText("third")
    XCTAssertTrue(app.buttons["Send"].isEnabled)
  }
}
