//  Stories 940, 941 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a kept
//  text made by To text (the fake reads every picture as "hello"), a finger tap on it, and its words changed or emptied
//  in the field that opens where it is. That one undo brings the old words back, and how it looks on the iPad, are the
//  iPad's to show; the words, the wrap and Larry's event are `BoardRewordTests`, on the host.

import XCTest

final class WhiteboardRewordUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board on paper with Ghosts off, one stroke made a kept "hello" by To text: the app, and the text on screen.
  private func boardWithAText() throws -> (XCUIApplication, PaperScreen.Box) {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_WHITEBOARD_AFTER_INK"] = "select"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertTrue(toText.appears(within: 10), "To text beside the selection: \(app.debugDescription)")
    toText.tap()
    waitUntil(
      NSPredicate(format: "label BEGINSWITH 'Send to Larry, ' AND label != 'Send to Larry, 1 strokes'"), send,
      timeout: 15)
    let text = try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "the kept text shows")
    return (app, text)
  }

  /// The field the tap opens.
  private func field(_ app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "whiteboard-reword").firstMatch
  }

  /// Story 940: a tap on the text opens its words; more words and Return draw them in its place, wider, from its left.
  func testATapOnAKeptTextRewordsItInPlace() throws {
    let (app, before) = try boardWithAText()
    let send = app.buttons["whiteboard-send"]
    let glyphs = send.label
    PaperScreen.tap(app, before.center)
    let words = field(app)
    XCTAssertTrue(words.appears(within: 5), "the field opens: \(app.debugDescription)")
    XCTAssertEqual(words.value as? String, "hello", "with the text's words in it")
    words.typeText(" world\n")
    // Return is done.
    wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: words)], timeout: 5)
    waitUntil(NSPredicate(format: "label != %@", glyphs), send, timeout: 10)
    XCTAssertFalse(app.buttons["copy-error"].exists, "no problem")
    // The new words are drawn a beat after the field goes: wait for ink wider than "hello", then for it to settle. A
    // settled read alone could take the old words, still on screen (context-grabber-yfrl).
    let wider = { (screen: PaperScreen) in screen.ink.flatMap { $0.width > before.width * 1.5 ? $0 : nil } }
    let after = try XCTUnwrap(
      PaperScreen.settled(app, within: 10, wider),
      "hello world is wider than hello: \(String(describing: PaperScreen(app).ink)) against \(before)")
    XCTAssertEqual(after.minX, before.minX, accuracy: 0.01, "from the same left")
  }

  /// Story 941: emptied, the text goes.
  func testEmptyWordsDeleteTheText() throws {
    let (app, before) = try boardWithAText()
    PaperScreen.tap(app, before.center)
    let words = field(app)
    XCTAssertTrue(words.appears(within: 5), app.debugDescription)
    words.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "\n")
    // Return is done.
    wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: words)], timeout: 5)
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, 0 strokes"), app.buttons["whiteboard-send"], timeout: 10)
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "no ink left")
  }
}
