//  Story 890 (#999) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a word
//  scratched out stays gone when he writes on. On Igor's iPad the scratch-out fired, and the next stroke brought the
//  word back, on the screen and to Larry. XCUITest can only drag straight, so `GRABBER_WHITEBOARD_ZIGZAG` reads the
//  second stroke as a fast zigzag across its own frame; what counts as a zigzag is `WhiteboardScratchOutTests`, on the
//  host, and the Pencil's own zigzag is the iPad's.

import XCTest

/// Story 890: scratched out, it stays gone; Undo and Redo still bring it back and take it again.
final class WhiteboardScratchOutUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  func testAScratchedOutWordStaysGoneWhenHeWritesOn() throws {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    app.launchEnvironment["GRABBER_WHITEBOARD_ZIGZAG"] = "2"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    sleep(1)
    let send = app.buttons["whiteboard-send"]
    // A "word", then the stroke the hook reads as a zigzag over it.
    point(app, 0.20, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.35))
    wait(send, label: "Send to Larry, 1 strokes")
    point(app, 0.18, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.47, 0.35))
    wait(send, label: "Send to Larry, 0 strokes")
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
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "after writing on"
    picture.lifetime = .keepAlways
    add(picture)
    XCTAssertGreaterThan(ink.minY, 0.5, "nothing left where the word was: \(ink)")
  }
}
