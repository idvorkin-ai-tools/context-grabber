//  Stories 853, 855, 858, 901 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts
//  it): a paste's Delete, a margin tap that makes a header and folds it, a fold's lines beside it, and the hold menu.
//  Where things land, how a section ends and what a fold moves are `BoardRoomTests` and `BoardOutlineTests` on the
//  host; these check the gestures reach them on paper.

import XCTest

final class WhiteboardOutlineUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, with Ghosts off so nothing else lands on it.
  private func openBoard(_ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    for (key, value) in extra { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    return app
  }

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

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  /// A short line of "writing" from `x` to `to`, at `y`, all screen fractions.
  private func write(_ app: XCUIApplication, x: CGFloat, to: CGFloat, y: CGFloat) {
    point(app, x, y).press(forDuration: 0.05, thenDragTo: point(app, to, y + 0.01))
  }

  /// The margin's left 64 board points: the first few percent of the screen at the board's fit.
  private let margin: CGFloat = 0.025

  private func marks(_ app: XCUIApplication, _ label: String) -> XCUIElementQuery {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
  }

  /// Story 853: a paste lands selected with Delete beside it, and Delete takes it away.
  func testAPasteLandsSelectedAndDeleteTakesItAway() throws {
    // HI is written in four single strokes: H three, I one (#996).
    let app = try openBoard(["GRABBER_WHITEBOARD_PASTE": "HI"])
    wait(send(app), label: strokes(4))
    let delete = app.buttons["whiteboard-paste-delete"]
    XCTAssertTrue(delete.appears(within: 5), "Delete beside the paste: \(app.debugDescription)")
    shot(app, "pasted, selected, with Delete")
    delete.tap()
    wait(send(app), label: strokes(0))
    XCTAssertFalse(delete.exists, "Delete goes with the paste")
  }

  /// Story 855: a margin tap beside a line makes it a header; a tap on its mark folds the indented line under it.
  func testAMarginTapMakesAHeaderAndAnotherFoldsIt() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.2, to: 0.5, y: 0.36)
    write(app, x: 0.12, to: 0.4, y: 0.44)
    wait(send(app), label: strokes(3))
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "a ▾ in the margin: \(app.debugDescription)")
    shot(app, "a header")
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), app.debugDescription)
    shot(app, "folded")
    let folded = marks(app, "Folded header").firstMatch.value as? String ?? ""
    XCTAssertTrue(folded.hasPrefix("▸ "), "its lines folded: \(folded)")
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "unfolded again")
  }

  /// Story 1030 (#967): a line drawn under a line of writing makes it a header as it lands, no margin tap. The
  /// "writing" is a slanted stroke, which no underline is; the indented line under it folds.
  func testAnUnderlineDrawnUnderALineMakesItAHeader() throws {
    let app = try openBoard()
    sleep(1)
    point(app, 0.15, 0.30).press(forDuration: 0.05, thenDragTo: point(app, 0.30, 0.32))
    point(app, 0.22, 0.38).press(forDuration: 0.05, thenDragTo: point(app, 0.40, 0.40))
    wait(send(app), label: strokes(2))
    XCTAssertFalse(marks(app, "Header").firstMatch.exists, "no header before the underline")
    point(app, 0.14, 0.33).press(forDuration: 0.05, thenDragTo: point(app, 0.31, 0.33))
    wait(send(app), label: strokes(3))
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "a ▾ in the margin: \(app.debugDescription)")
    shot(app, "underlined, a header")
    point(app, margin, 0.31).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), "it folds: \(app.debugDescription)")
    shot(app, "underlined header folded")
  }

  /// Stories 1040, 1041 (#1004): a line tints the moment it becomes a header; every header's ▾ sits in one spot
  /// across, over the ink, its foot on the line, and a tap on the ▾ itself folds it.
  func testHeaderMarksShareOneSpotStandOnTheLineAndTintWhenMade() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.3, to: 0.6, y: 0.44)
    write(app, x: 0.36, to: 0.6, y: 0.50)
    wait(send(app), label: strokes(3))
    point(app, margin, 0.305).tap()
    let tint = app.descendants(matching: .any)["whiteboard-header-tint"]
    XCTAssertTrue(tint.appears(within: 2), "the new header tints: \(app.debugDescription)")
    shot(app, "a header made, tinted")
    XCTAssertTrue(tint.waitForNonExistence(timeout: 4), "the tint fades")
    point(app, margin, 0.445).tap()
    let headers = marks(app, "Header")
    XCTAssertTrue(headers.element(boundBy: 1).appears(within: 5), "two headers: \(app.debugDescription)")
    let first = headers.element(boundBy: 0).frame
    let second = headers.element(boundBy: 1).frame
    XCTAssertEqual(first.minX, second.minX, accuracy: 1, "one spot across, whatever the indent")
    XCTAssertLessThan(first.maxX, app.frame.width * 0.08, "in the margin")
    // Each mark's foot on its line's baseline: the bottom of the line's ink, read from the screen's pixels (a drag's ink
    // ends a little short of where the drag does, so not from where it was drawn).
    let screen = PaperScreen(app)
    let lines = [(0.25, 0.37), (0.40, 0.475)].map { band in
      screen.ink(in: PaperScreen.Box(minX: 0.1, minY: band.0, maxX: 1, maxY: band.1)).map { $0.maxY * app.frame.height }
    }
    let feet = [first, second].map(\.maxY).sorted()
    for (foot, line) in zip(feet, lines) {
      let bottom = try XCTUnwrap(line, "the line's ink on screen")
      XCTAssertEqual(foot, bottom, accuracy: 4, "the mark stands on its line")
    }
    shot(app, "two headers, one spot")
    // A tap on the ▾ itself, near its top edge, folds it.
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: second.midX, dy: second.minY + 2)).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), "it folds: \(app.debugDescription)")
    shot(app, "folded from the ▾")
  }

  /// Stories 1044, 1038 (#1000): while the room handle is held, a see-through band and a chip say what the lift will
  /// do. The simulator can't look mid-drag, so `GRABBER_WHITEBOARD_FEEDBACK_SECONDS` keeps the band up after the lift.
  func testTheRoomHandleShowsABandWhileHeld() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_FEEDBACK_SECONDS": "8"])
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.12, to: 0.4, y: 0.40)
    wait(send(app), label: strokes(2))
    let band = app.descendants(matching: .any)["whiteboard-room-band"]
    XCTAssertFalse(band.exists, "no band before a hold")
    point(app, margin, 0.35).press(forDuration: 0.8, thenDragTo: point(app, margin, 0.45))
    XCTAssertTrue(band.appears(within: 3), "the band: \(app.debugDescription)")
    XCTAssertEqual(band.label, "Making room")
    XCTAssertNotEqual(band.value as? String, "0 lines", "as tall as the room it opened")
    shot(app, "making room: the band, arrows and chip")
    point(app, margin, 0.36).press(forDuration: 0.8, thenDragTo: point(app, margin, 0.33))
    waitUntil(NSPredicate(format: "label == %@", "Closing room"), band, timeout: 3)
    shot(app, "closing room: the band over the blank paper")
  }

  /// Story 901: a folded header says beside its row how many lines it holds, and the words go when it unfolds.
  func testAFoldShowsItsLinesBesideTheHeader() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.2, to: 0.5, y: 0.36)
    write(app, x: 0.12, to: 0.4, y: 0.44)
    wait(send(app), label: strokes(3))
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), app.debugDescription)
    point(app, margin, 0.305).tap()
    let folded = marks(app, "Lines folded").firstMatch
    XCTAssertTrue(folded.appears(within: 5), "the words beside the folded header: \(app.debugDescription)")
    let words = folded.value as? String ?? ""
    XCTAssertTrue(words.hasPrefix("▸ ") && words.hasSuffix("folded"), "▸ N lines folded: \(words)")
    XCTAssertGreaterThan(folded.frame.minX, app.frame.width * 0.3, "beside the header's row, not in the margin")
    shot(app, "folded, its lines beside it")
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "unfolded again")
    XCTAssertFalse(marks(app, "Lines folded").firstMatch.exists, "the words go with the fold")
  }

  /// Story 858: a finger held on the page brings up the menu; held in the margin and dragged it opens room.
  func testAHoldBringsTheMenuAndAMarginDragMakesRoom() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.12, to: 0.4, y: 0.40)
    wait(send(app), label: strokes(2))
    point(app, 0.7, 0.6).press(forDuration: 1.0)
    let makeRoom = app.buttons["whiteboard-hold-make-room"]
    XCTAssertTrue(makeRoom.appears(within: 5), "the hold menu: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["whiteboard-hold-paste"].exists)
    shot(app, "the hold menu")
    makeRoom.tap()
    XCTAssertFalse(makeRoom.appears(within: 2), "the menu goes once chosen")
    point(app, 0.7, 0.30).press(forDuration: 1.0)
    XCTAssertTrue(app.buttons["whiteboard-hold-make-header"].appears(within: 5), "beside a line: Make header")
    app.buttons["whiteboard-hold-make-header"].tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5))
    point(app, margin, 0.35).press(forDuration: 0.8, thenDragTo: point(app, margin, 0.45))
    shot(app, "room opened by the margin")
    XCTAssertFalse(app.buttons["whiteboard-hold-make-room"].exists, "a drag is room, not the menu")
  }
}
