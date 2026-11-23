//  Story 890 (#999) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a word
//  scratched out stays gone when he writes on. On Igor's iPad the scratch-out fired, and the next stroke brought the
//  word back, on the screen and to Larry. XCUITest can only drag straight, so `GRABBER_WHITEBOARD_ZIGZAG` reads the
//  second stroke as a fast zigzag across its own frame; what counts as a zigzag is `WhiteboardScratchOutTests`, on the
//  host, and the Pencil's own zigzag is the iPad's.

import XCTest

/// Stories 890, 905, 1050, 1051 and 1108: a scratch-out takes what it covers and it stays gone; the eraser never is one.
final class WhiteboardScratchOutUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  /// Story 905 (si4t): a scratch-out over a folded header takes the fold, and the fold stays gone when he writes on.
  func testAScratchedOutFoldStaysGoneWhenHeWritesOn() throws {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    app.launchEnvironment["GRABBER_WHITEBOARD_ZIGZAG"] = "4"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    sleep(1)
    let send = app.buttons["whiteboard-send"]
    let marks = { (label: String) in
      app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    // A header, the indented line it folds, and a line after the section; the margin's taps make it a header and fold it.
    point(app, 0.12, 0.30).press(forDuration: 0.05, thenDragTo: point(app, 0.40, 0.31))
    point(app, 0.20, 0.36).press(forDuration: 0.05, thenDragTo: point(app, 0.50, 0.37))
    point(app, 0.12, 0.44).press(forDuration: 0.05, thenDragTo: point(app, 0.40, 0.45))
    wait(send, label: "Send to Larry, 3 strokes")
    point(app, 0.025, 0.305).tap()
    XCTAssertTrue(marks("Header").appears(within: 5), app.debugDescription)
    point(app, 0.025, 0.305).tap()
    XCTAssertTrue(marks("Folded header").appears(within: 5), app.debugDescription)
    // The stroke the hook reads as a zigzag, over the folded header's line: the fold goes, header and line.
    point(app, 0.10, 0.305).press(forDuration: 0.05, thenDragTo: point(app, 0.42, 0.305))
    wait(send, label: "Send to Larry, 1 strokes")
    XCTAssertFalse(marks("Folded header").exists, "the fold is gone")
    // Writing on, below: the fold's ink never comes back.
    point(app, 0.20, 0.70).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.70))
    wait(send, label: "Send to Larry, 2 strokes")
    sleep(1)
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "after writing on"
    picture.lifetime = .keepAlways
    add(picture)
    XCTAssertEqual(send.label, "Send to Larry, 2 strokes", "the scratched-out fold never comes back")
    XCTAssertFalse(marks("Folded header").exists, "no fold came back")
  }

  /// A new board on paper with Ghosts off, the hook reading stroke `zigzag` as a zigzag, feedback held `seconds`.
  private func openBoard(zigzag: Int, seconds: Int) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    app.launchEnvironment["GRABBER_WHITEBOARD_ZIGZAG"] = "\(zigzag)"
    app.launchEnvironment["GRABBER_WHITEBOARD_FEEDBACK_SECONDS"] = "\(seconds)"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    sleep(1)
    return app
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Stories 890 (#999) and 1050 (#1000): the struck ink flashes where it was as it goes (the hook holds it up for the
  /// picture); scratched out, it stays gone, and Undo and Redo still bring it back and take it again.
  func testAScratchedOutWordFlashesAndStaysGoneWhenHeWritesOn() throws {
    let app = try openBoard(zigzag: 2, seconds: 6)
    let send = app.buttons["whiteboard-send"]
    // A "word", then the stroke the hook reads as a zigzag over it.
    point(app, 0.20, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.35))
    wait(send, label: "Send to Larry, 1 strokes")
    point(app, 0.18, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.47, 0.35))
    wait(send, label: "Send to Larry, 0 strokes")
    let flash = app.descendants(matching: .any)["whiteboard-scratch-flash"]
    XCTAssertTrue(flash.appears(within: 3), "the flash: \(app.debugDescription)")
    shot(app, "scratched out: the struck ink flashing")
    XCTAssertFalse(app.descendants(matching: .any)["whiteboard-scratch-nothing"].exists, "no word when it worked")
    XCTAssertTrue(flash.disappears(within: 15), "the flash fades: \(app.debugDescription)")
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "the word and the zigzag are gone from the sheet")
    // One Undo brings the word back without the zigzag, and Redo takes it again.
    app.buttons["whiteboard-undo"].tap()
    wait(send, label: "Send to Larry, 1 strokes")
    XCTAssertNotNil(PaperScreen.settled(app) { $0.ink }, "Undo brings the word back to the sheet")
    app.buttons["whiteboard-redo"].tap()
    wait(send, label: "Send to Larry, 0 strokes")
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "Redo takes it again")
    // Writing on, below: only the new stroke is ink.
    point(app, 0.20, 0.60).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.60))
    wait(send, label: "Send to Larry, 1 strokes")
    sleep(1)
    XCTAssertEqual(send.label, "Send to Larry, 1 strokes", "the scratched-out word never comes back")
    let ink = try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "the new stroke on the sheet")
    shot(app, "after writing on")
    XCTAssertGreaterThan(ink.minY, 0.5, "nothing left where the word was: \(ink)")
  }

  /// Stories 1108 (#1121) and 1051 (#1000). The eraser drawn across ink is the eraser, never a scratch-out, whatever its
  /// shape: on the iPad PaperKit handed the board a passing stroke for the eraser's sweep; the board read a fast one as
  /// a zigzag, pressed PaperKit's Undo for it, and PaperKit trapped inside that Undo. The hook reads the eraser's sweep,
  /// the second stroke, as a zigzag. Then a zigzag on bare paper goes, with a word, and Redo brings it back as ink.
  func testTheEraserIsNeverAScratchOutAndAZigzagOverNothingSaysSo() throws {
    let app = try openBoard(zigzag: 2, seconds: 6)
    let send = app.buttons["whiteboard-send"]
    point(app, 0.20, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.35))
    wait(send, label: "Send to Larry, 1 strokes")
    app.buttons["Eraser"].tap()
    sleep(1)
    point(app, 0.18, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.47, 0.35))
    let flash = app.descendants(matching: .any)["whiteboard-scratch-flash"]
    XCTAssertFalse(flash.appears(within: 3), "the eraser's sweep fired a scratch-out: \(app.debugDescription)")
    let nothing = app.descendants(matching: .any)["whiteboard-scratch-nothing"]
    XCTAssertFalse(nothing.exists, "the eraser's sweep read as a zigzag")
    shot(app, "the eraser drawn across a word")
    XCTAssertEqual(app.state, .runningForeground, "the app is still up after the eraser's sweep")
    app.buttons["Pen"].tap()
    sleep(1)
    // The hook reads the stroke that brings the board to two as the zigzag: one stroke on the board first, then the
    // zigzag far below it, on bare paper.
    if send.label == "Send to Larry, 0 strokes" {
      point(app, 0.20, 0.25).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.25))
      wait(send, label: "Send to Larry, 1 strokes")
    }
    XCTAssertEqual(send.label, "Send to Larry, 1 strokes", "one stroke on the board before the zigzag")
    point(app, 0.20, 0.70).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.70))
    XCTAssertTrue(nothing.appears(within: 5), "the word: \(app.debugDescription)")
    XCTAssertEqual(nothing.label, "Nothing under the scribble to erase")
    wait(send, label: "Send to Larry, 1 strokes")
    shot(app, "a zigzag over nothing: taken away, with a word")
    app.buttons["whiteboard-redo"].tap()
    wait(send, label: "Send to Larry, 2 strokes")
  }
}
