//  Story 303 (#448) on the simulator: the Deepgram key is saved and removed in Settings → Voice in Chat without ever
//  showing, and with no key the thread's mic says where to add one instead of recording.

import XCTest

final class ChatVoiceUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testTheKeyIsSavedAndRemovedAndWithoutOneTheMicSaysWhere() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launch()
    app.openHomeSettings()
    let remove = app.buttons["voice-key-remove"]
    if remove.waitForExistence(timeout: 3) { remove.tap() }  // whatever an earlier run left
    let field = app.secureTextFields["voice-key-field"]
    XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["voice-key-save"].isEnabled, "nothing to save yet")
    field.tap()
    field.typeText("not-a-real-key")
    app.buttons["voice-key-save"].tap()
    let saved = app.descendants(matching: .any)["voice-key-saved"]
    XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.staticTexts["not-a-real-key"].exists, "the key is never shown")
    app.buttons["voice-key-remove"].tap()
    XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
    app.terminate()

    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    // The thread's identifier covers its children, so the mic and its line are found by their labels.
    let mic = app.buttons["Speak a message"]
    XCTAssertTrue(mic.waitForExistence(timeout: 20), app.debugDescription)
    mic.tap()
    let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Settings → Voice in Chat"))
      .firstMatch
    XCTAssertTrue(notice.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Stop recording"].exists, "no recording started")
  }
}
