//  Stories 390–393 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it), read
//  from the Send button's label (the strokes drawn). HI is two strokes, one a letter. XCUITest's taps never reach the
//  system's paste button, so the button is the iPad's check and these go through ⌘V or GRABBER_WHITEBOARD_PASTE.

import XCTest

final class WhiteboardPasteUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit.
  private func openBoard(pasting text: String? = nil) throws -> XCUIApplication {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    if let text { app.launchEnvironment["GRABBER_WHITEBOARD_PASTE"] = text }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.waitForExistence(timeout: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    return app
  }

  private func wait(_ app: XCUIApplication, strokes: Int) {
    let send = app.buttons["whiteboard-send"]
    expectation(for: NSPredicate(format: "label == %@", "Send to Larry, \(strokes) strokes"), evaluatedWith: send)
    waitForExpectations(timeout: 8)
  }

  /// The board's note, which also says how many suggestions show.
  private func waitForNote(_ app: XCUIApplication, saying words: String) {
    let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    XCTAssertTrue(note.waitForExistence(timeout: 8), app.debugDescription)
  }

  /// First in the class on purpose: on the simulator only the first test of a run gets its keys through (seen in three
  /// runs; a later launch's ⌘V never reaches the app).
  func testACommandVPastesTheClipboardAndCommandZTakesItAllBack() throws {
    UIPasteboard.general.string = "HI"
    let app = try openBoard()
    sleep(1)
    app.typeKey("v", modifierFlags: .command)
    wait(app, strokes: 2)
    app.typeKey("z", modifierFlags: .command)
    wait(app, strokes: 0)
  }

  func testEachLineIsInkAndClaudesPauseStarts() throws {
    let app = try openBoard(
      pasting: "Plan for Tuesday\nCall the bank, then a long line that wraps across the phone\n\nHI")
    XCTAssertTrue(app.buttons["whiteboard-paste"].exists)
    let ghosts = app.buttons["whiteboard-ghosts"]
    expectation(for: NSPredicate(format: "label == %@", "Ghosts on, 1 showing"), evaluatedWith: ghosts)
    waitForExpectations(timeout: 10)
  }

  func testTheStrokesAreOneALetterOutline() throws {
    wait(try openBoard(pasting: "HI\nHI"), strokes: 4)
  }

  func testALongPasteIsCutAndTheBarSaysSo() throws {
    let app = try openBoard(pasting: String(repeating: "I", count: 1234))
    wait(app, strokes: 500)
    waitForNote(app, saying: "Pasted the first 500 of 1,234 characters")
  }

  func testOnlyEmojiLeavesTheBoardAloneAndSaysSo() throws {
    let app = try openBoard(pasting: "🎉🎉")
    waitForNote(app, saying: "Nothing in that text can be drawn")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 0 strokes")
  }
}
