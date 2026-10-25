//  Story 274 (#449): after a send the bar is empty, with the keyboard still up for the next message.

import XCTest

final class ChatComposeClearsUITests: XCTestCase {
  func testTheBarEmptiesAfterASend() throws {
    let app = XCUIApplication()
    // A Cockpit nobody answers on: the message waits on the phone and nothing reaches Larry.
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    // The thread's identifier covers its children, so the bar is found by kind and label, as the other tests do.
    XCTAssertTrue(app.otherElements["chat-thread"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
    let compose = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    XCTAssertTrue(compose.waitForExistence(timeout: 5), app.debugDescription)
    compose.tap()
    compose.typeText("first of two")
    app.buttons["Send"].tap()
    // The first send asks for notifications (chat spec); a clean simulator shows the system alert, so answer it.
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
    XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard stays up for the next message")
    XCTAssertFalse(app.buttons["Send"].isEnabled, "nothing left to send twice")
    // Straight on, with no tap on the field: the next message goes in where the last one was.
    field.typeText("second")
    XCTAssertTrue(app.buttons["Send"].isEnabled)
  }
}
