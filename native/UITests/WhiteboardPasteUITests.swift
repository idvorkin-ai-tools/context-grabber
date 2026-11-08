//  Stories 390–393, 638 and 639 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it),
//  read from the Send button's label (the strokes drawn). HI is two strokes, one a letter. The text's layout, its caps, a
//  stroke a letter and what the bar says are `WhiteboardPasteTests`, on the host; these are the keys, the canvas and the
//  bar. XCUITest's taps never reach the system's paste button, so the button is the iPad's check and these go through
//  ⌘V or GRABBER_WHITEBOARD_PASTE. What a page adds to a paste is `WhiteboardPaperPasteUITests`.

import XCTest

final class WhiteboardPasteUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit.
  private func openBoard(pasting text: String? = nil) throws -> XCUIApplication {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "off"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    if let text { app.launchEnvironment["GRABBER_WHITEBOARD_PASTE"] = text }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    return app
  }

  private func wait(_ app: XCUIApplication, strokes: Int) {
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, \(strokes) strokes"), app.buttons["whiteboard-send"],
      timeout: 8)
  }

  /// The board's note, which also says how many suggestions show.
  private func waitForNote(_ app: XCUIApplication, saying words: String) {
    let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    XCTAssertTrue(note.appears(within: 8), app.debugDescription)
  }

  private func stroke(_ app: XCUIApplication) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.3)))
  }

  /// Stories 390, 638, 639: ⌘V pastes the clipboard and ⌘Z takes it all back, on the old canvas and then on a board on
  /// paper, whose keys are its own. On the simulator, keys reach the app only in the first test after a boot that presses
  /// any (seen in three runs), so this is the suite's one test that presses keys, both canvases in one launch, and the
  /// suite needs one boot.
  func testCommandVPastesAndCommandZTakesItBackOnBothCanvases() throws {
    UIPasteboard.general.string = "HI"
    let app = try openBoard()
    sleep(1)
    app.typeKey("v", modifierFlags: .command)
    wait(app, strokes: 2)
    app.typeKey("z", modifierFlags: .command)
    wait(app, strokes: 0)

    // New boards on paper, from the list's menu, and one of them.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let options = app.buttons["whiteboard-options"]
    XCTAssertTrue(options.appears(within: 10), app.debugDescription)
    options.tap()
    let toggle = app.descendants(matching: .any)["New boards on paper"].firstMatch
    XCTAssertTrue(toggle.appears(within: 5), app.debugDescription)
    toggle.tapWhenSettled()
    expectation(for: NSPredicate(format: "label == %@", "Board options, new boards on paper"), evaluatedWith: options)
    waitForExpectations(timeout: 10)
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 5), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    // Ghosts off, so nothing else lands on the paper.
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch.appears(within: 10),
      "a board on paper" + app.debugDescription)
    sleep(2)
    // The first ink brings the next page, which on a phone moves the view: the paste comes after it.
    stroke(app)
    wait(app, strokes: 1)
    sleep(1)
    app.typeKey("v", modifierFlags: .command)
    wait(app, strokes: 3)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "pasted with keys on paper"
    shot.lifetime = .keepAlways
    add(shot)
    app.typeKey("z", modifierFlags: .command)
    wait(app, strokes: 1)
  }

  /// Stories 390, 391: each letter is a stroke on the canvas, and a paste starts Claude's pause as a drawn stroke does.
  func testEachLetterIsAStrokeAndClaudesPauseStarts() throws {
    let app = try openBoard(pasting: "HI\nHI")
    XCTAssertTrue(app.buttons["whiteboard-paste"].appears(within: 5))
    wait(app, strokes: 4)
    let ghosts = app.buttons["whiteboard-ghosts"]
    expectation(for: NSPredicate(format: "label == %@", "Ghosts on, 1 showing"), evaluatedWith: ghosts)
    waitForExpectations(timeout: 10)
  }

  /// Story 393: the bar shows the paste's note. Which note, and the 500-character cap, are `WhiteboardPasteTests`'.
  func testOnlyEmojiLeavesTheBoardAloneAndSaysSo() throws {
    let app = try openBoard(pasting: "🎉🎉")
    waitForNote(app, saying: "Nothing in that text can be drawn")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 0 strokes")
  }
}
