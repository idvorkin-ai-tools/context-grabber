//  Story 274 (#449): after a send the bar is empty, with the keyboard still up for the next message.

import XCTest

final class ChatComposeClearsUITests: XCTestCase {
  func testTheBarEmptiesAfterASend() throws {
    let app = XCUIApplication()
    // A Cockpit nobody answers on: the message waits on the phone and nothing reaches Larry.
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    let compose = app.descendants(matching: .any)["chat-compose"]
    XCTAssertTrue(compose.waitForExistence(timeout: 15), app.debugDescription)
    compose.tap()
    compose.typeText("first of two")
    app.buttons["chat-send"].tap()
    // The first send asks for notifications (chat spec); a clean simulator shows the system alert, so answer it.
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.waitForExistence(timeout: 3) {
      allow.tap()
      app.descendants(matching: .any)["chat-compose"].tap()
    }

    let field = app.descendants(matching: .any)["chat-compose"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    let empty = NSPredicate { _, _ in
      ((field.value as? String) ?? "").replacingOccurrences(of: "Message Larry", with: "").isEmpty
    }
    expectation(for: empty, evaluatedWith: field)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard stays up for the next message")
    XCTAssertFalse(app.buttons["chat-send"].isEnabled, "nothing left to send twice")
    // Straight on, with no tap on the field: the next message goes in where the last one was.
    field.typeText("second")
    XCTAssertTrue(app.buttons["chat-send"].isEnabled)
  }
}
