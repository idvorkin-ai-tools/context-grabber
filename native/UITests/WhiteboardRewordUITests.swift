//  Stories 940, 941, 1197 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a
//  kept text made by To text (the fake reads every picture as "hello"), a finger tap that selects it and a second that
//  opens it, and its words changed or emptied
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
    XCTAssertTrue(app.selectionLabel.appears(within: 10), "the ink selected: \(app.debugDescription)")
    app.toTextFromHold(at: CGVector(dx: 0.45, dy: 0.5))
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

  /// Story 1197: the first tap selects the text (its label says so, no field); the second opens it.
  private func selectThenOpen(_ app: XCUIApplication, _ text: PaperScreen.Box) -> XCUIElement {
    PaperScreen.tap(app, text.center)
    let named = app.descendants(matching: .any)["whiteboard-selection-label"]
    XCTAssertTrue(named.appears(within: 5), "the first tap selected the text: \(app.debugDescription)")
    XCTAssertEqual(named.label, "Selected: Text, tap to reword")
    let words = field(app)
    XCTAssertFalse(words.exists, "the first tap opens no field")
    sleep(2)  // past the selection PaperKit makes of the same tap
    PaperScreen.tap(app, text.center)
    return words
  }

  /// Story 940: a second tap on the text opens its words; more words and Return draw them in its place, wider, from its
  /// left.
  func testATapOnAKeptTextRewordsItInPlace() throws {
    let (app, before) = try boardWithAText()
    let send = app.buttons["whiteboard-send"]
    let glyphs = send.label
    let words = selectThenOpen(app, before)
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

  /// Stories 1197, 1201: a drag after the first tap moves the text where the finger goes, at its size, and opens nothing.
  func testAFirstTapPicksUpATextToDrag() throws {
    let (app, before) = try boardWithAText()
    let send = app.buttons["whiteboard-send"]
    let glyphs = send.label
    PaperScreen.tap(app, before.center)
    let named = app.descendants(matching: .any)["whiteboard-selection-label"]
    XCTAssertTrue(named.appears(within: 5), "the first tap selected the text: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: before.center.x, dy: before.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: before.center.x, dy: before.center.y + 0.1))
    // Slow, and held before the lift, as the group's drag (bead context-grabber-z93g).
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    // Story 1201: down, as the finger went, at its size. PaperKit's resize handles cover a text this small, and the drag
    // stretched it sideways (ink_moved dx -34, dy 0 for a drag 120 points down; bead context-grabber-vhae); the board
    // takes the stretch back on the lift and moves it by the finger's travel. PaperKit's drag begins a few points in,
    // so the move may be a little short of the finger's. Read where it should be, below the selection's label, which sits
    // just above the text.
    let landing = PaperScreen.Box(
      minX: before.minX - 0.03, minY: before.minY + 0.08, maxX: before.maxX + 0.03, maxY: before.maxY + 0.15)
    let moved = try XCTUnwrap(
      PaperScreen.settled(app, within: 10) { $0.ink(in: landing) },
      "the text moved down from \(before): \(String(describing: PaperScreen(app).ink))")
    // The label reaches into the region on its right and above, so the text's left and bottom edges are what is read: a
    // stretch moved the left edge 0.04 to the left and left the bottom where it was.
    XCTAssertEqual(moved.maxY - before.maxY, 0.1, accuracy: 0.03, "as far down as the finger went: \(moved)")
    XCTAssertEqual(moved.minX, before.minX, accuracy: 0.01, "and not across, nor stretched: \(moved)")
    // One Undo puts it back where it was.
    let undo = app.buttons["whiteboard-undo"]
    XCTAssertTrue(undo.appears(within: 5), app.debugDescription)
    undo.tap()
    let back = PaperScreen.Box(
      minX: before.minX - 0.03, minY: before.minY - 0.01, maxX: before.maxX + 0.03, maxY: before.maxY + 0.01)
    XCTAssertNotNil(
      PaperScreen.settled(app, within: 10) {
        $0.ink(in: back).flatMap { abs($0.minX - before.minX) < 0.01 ? $0 : nil }
      },
      "one Undo put it back at \(before): \(String(describing: PaperScreen(app).ink))")
    XCTAssertNil(PaperScreen(app).ink(in: landing), "and nothing is left where it landed")
    XCTAssertFalse(field(app).exists, "a drag opens no field")
    XCTAssertEqual(send.label, glyphs, "moved, not drawn")
  }

  /// Story 1151: a small text dragged from inside onto a line drops there and pushes the line down (story 973).
  func testASmallTextDroppedOnALinePushesItDown() throws {
    let (app, before) = try boardWithAText()
    // A line under where the text will land, drawn with nothing selected.
    let lineY = before.maxY + 0.1
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: lineY))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: lineY)))
    let underLine = PaperScreen.Box(minX: 0.2, minY: lineY + 0.008, maxX: 0.55, maxY: lineY + 0.15)
    sleep(2)
    XCTAssertNil(PaperScreen(app).ink(in: underLine), "nothing under the line yet")
    PaperScreen.tap(app, before.center)
    let named = app.descendants(matching: .any)["whiteboard-selection-label"]
    XCTAssertTrue(named.appears(within: 5), "the tap selected the text: \(app.debugDescription)")
    sleep(2)
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: before.center.x, dy: before.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: before.center.x, dy: before.center.y + 0.1))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    XCTAssertNotNil(
      PaperScreen.settled(app, within: 10) { $0.ink(in: underLine) },
      "the line went down clear of the text: \(String(describing: PaperScreen(app).ink))")
  }

  /// Story 1150: a drag from a corner's knob, even the part of it inside the selection, still stretches.
  func testAStretchFromACornerKnobStillStretches() throws {
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
    // A diagonal, selected a second after it is drawn: its box's bottom-right corner is about (0.6, 0.55).
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.55)))
    XCTAssertTrue(app.selectionLabel.appears(within: 10), "selected: \(app.debugDescription)")
    sleep(1)
    // Below the selection's label, above its box.
    let below = PaperScreen.Box(minX: 0.2, minY: 0.45, maxX: 0.9, maxY: 0.74)
    let before = try XCTUnwrap(PaperScreen.settled(app) { $0.ink(in: below) }, "the line shows")
    let knob = app.coordinate(withNormalizedOffset: CGVector(dx: 0.606, dy: 0.541))
    knob.press(
      forDuration: 0.3, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.62)),
      withVelocity: 200, thenHoldForDuration: 0.5)
    let after = try XCTUnwrap(
      PaperScreen.settled(app, within: 10) { $0.ink(in: below).flatMap { $0.maxX > before.maxX + 0.02 ? $0 : nil } },
      "the line stretched past \(before): \(String(describing: PaperScreen(app).ink(in: below)))")
    XCTAssertGreaterThan(after.maxY, before.maxY + 0.02, "down as well: \(after)")
  }

  /// Story 941: emptied, the text goes.
  func testEmptyWordsDeleteTheText() throws {
    let (app, before) = try boardWithAText()
    let words = selectThenOpen(app, before)
    XCTAssertTrue(words.appears(within: 5), app.debugDescription)
    words.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "\n")
    // Return is done.
    wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: words)], timeout: 5)
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, 0 strokes"), app.buttons["whiteboard-send"], timeout: 10)
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "no ink left")
  }
}
