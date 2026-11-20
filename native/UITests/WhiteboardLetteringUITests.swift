//  #950 (stories 1044, 1045) on the iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts
//  it): the Board menu's Lettering, and a paste in the real font. The outlines, a text's own lettering, reword and the
//  per-board memory are `BoardRealFontTests`, on the host. XCUITest's taps never reach the system's paste button, so the
//  paste goes through the paste hook, as `WhiteboardPaperPasteUITests` does, which pastes each time the board opens.

import XCTest

final class WhiteboardLetteringUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, with Ghosts off so nothing else lands on it. The paste hook pastes "HI" a second after each
  /// time the board opens.
  private func openBoard() throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD_PASTE"] = "HI"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    return app
  }

  private func board(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-board"] }
  private func send(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-send"] }
  private func strokes(_ count: Int) -> String { "Send to Larry, \(count) strokes" }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Stories 1044, 1045: a new board letters in single strokes ("HI" is four strokes) until the Board menu's Real font
  /// is on; then, the board left and opened again, it still is, and "HI" is Helvetica's two closed outlines. A new board
  /// after it is single strokes again.
  func testRealFontFromTheBoardMenuLettersAPasteInTheFontsOutlines() throws {
    let app = try openBoard()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    wait(send(app), label: strokes(4))
    XCTAssertFalse(board(app).label.hasSuffix(", real font"), "a new board letters in single strokes")
    shot(app, "HI in single strokes")
    board(app).tap()
    let realFont = app.descendants(matching: .any)["whiteboard-lettering"].firstMatch
    XCTAssertTrue(realFont.appears(within: 5), app.debugDescription)
    shot(app, "the Board menu with Real font")
    // #880: the iPad simulator's on-screen keyboard rising under a menu cancels a tap that lands as it rises, so the row
    // is tapped again, at most twice more, only while the menu is still up and the pick didn't take.
    let took = { self.board(app).exists && self.board(app).label.hasSuffix(", real font") }
    for _ in 0..<3 {
      realFont.tapWhenSettled()
      let deadline = Date().addingTimeInterval(2)
      while Date() < deadline, !took() { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
      guard !took(), realFont.exists, realFont.isHittable else { break }
      print("ui-menu: the tap on Real font didn't take; tapping it again (#880)")
    }
    waitUntil(NSPredicate(format: "label ENDSWITH ', real font'"), board(app), timeout: 10)
    XCTAssertEqual(send(app).label, strokes(4), "turning it on redraws nothing")
    sleep(1)  // The menu gone, and the board saved.

    // Opened again, the board remembers, and the hook's paste is in the font: H and I one outline each.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons.matching(identifier: "whiteboard-card").firstMatch
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    card.tap()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    waitUntil(NSPredicate(format: "label ENDSWITH ', real font'"), board(app), timeout: 10)
    wait(send(app), label: strokes(6), timeout: 15)
    sleep(2)
    shot(app, "HI pasted again in the real font, beside the single strokes")

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 10), app.debugDescription)
    new.tap()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    wait(send(app), label: strokes(4))
    XCTAssertFalse(board(app).label.hasSuffix(", real font"), "another board's lettering is its own")
  }
}
