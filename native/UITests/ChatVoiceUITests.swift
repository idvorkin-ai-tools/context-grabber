//  Story 303 (#448) on the simulator: the chat mic is the problem report's Apple dictation, so Settings asks for no
//  key, and the thread's mic and its microphone picker are there and ready. Speaking itself needs the phone (the
//  recognizer, the microphone).

import XCTest

final class ChatVoiceUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testNoKeyIsAskedForAndTheThreadsMicAndPickerAreReady() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launch()
    app.openHomeSettings()
    XCTAssertTrue(app.buttons["home-settings-launchers"].waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.staticTexts["Voice in Chat"].exists, "no Deepgram key section any more")
    XCTAssertFalse(app.secureTextFields["voice-key-field"].exists, "no Deepgram key field any more")
    app.terminate()

    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    // The thread's identifier covers its children, so the mic is found by its label.
    let mic = app.buttons["Speak a message"]
    XCTAssertTrue(mic.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertTrue(mic.isEnabled, "no call is live, so the mic is ready")
    XCTAssertFalse(app.buttons["Stop recording"].exists, "nothing records until a tap")
    let picker = app.buttons["Microphone: Automatic"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5), "the microphone picker, on Automatic: \(app.debugDescription)")
    picker.tap()
    XCTAssertTrue(app.buttons["Find microphones"].waitForExistence(timeout: 5), app.debugDescription)
  }
}
