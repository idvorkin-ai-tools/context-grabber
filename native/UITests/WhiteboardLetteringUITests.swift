//  #950 (stories 1044, 1045) on the iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts
//  it): the Board menu's Lettering, and a paste in the real font. The outlines, a text's own lettering, reword and the
//  per-board memory are `BoardRealFontTests`, on the host. XCUITest's taps never reach the system's paste button, so the
//  paste goes through the after-ink hook, as `WhiteboardPaperPasteUITests` does.

import XCTest

final class WhiteboardLetteringUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, with Ghosts off so nothing else lands on it, that pastes the clipboard after its first ink.
  private func openBoard() throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD_AFTER_INK"] = "paste"
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

  /// A row of the open menu, tapped until it takes (#880: the iPad simulator's on-screen keyboard rising under a menu
  /// cancels a tap that lands as it rises), at most three times, and only while the row is still up and `took` isn't.
  private func tapRow(_ app: XCUIApplication, _ label: String, took: () -> Bool) {
    let row = app.descendants(matching: .any)[label].firstMatch
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)
    for _ in 0..<3 {
      row.tapWhenSettled()
      let deadline = Date().addingTimeInterval(2)
      while Date() < deadline, !took() { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
      guard !took(), row.exists, row.isHittable else { break }
      print("ui-menu: the tap on \(label) didn't take; tapping it again (#880)")
    }
  }

  /// Stories 1044, 1045: a board letters in single strokes until Lettering says Real font; then a paste of "HI" is
  /// Helvetica's two outlines, one closed loop a letter, where single strokes write it in four.
  func testRealFontFromTheBoardMenuLettersAPasteInTheFontsOutlines() throws {
    UIPasteboard.general.string = "HI"
    let app = try openBoard()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    XCTAssertFalse(board(app).label.hasSuffix(", real font"), "a new board letters in single strokes")
    board(app).tap()
    tapRow(app, "Lettering: Single strokes") { app.descendants(matching: .any)["Real font"].firstMatch.exists }
    shot(app, "the Lettering submenu")
    tapRow(app, "Real font") { self.board(app).label.hasSuffix(", real font") }
    waitUntil(NSPredicate(format: "label ENDSWITH ', real font'"), board(app), timeout: 10)
    wait(send(app), label: strokes(0))
    sleep(1)  // The menu gone and the sheet laid.
    // One stroke, then the hook pastes the clipboard a second later.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.3)))
    wait(send(app), label: strokes(3), timeout: 15)
    sleep(2)
    shot(app, "HI pasted in the real font")
  }
}
