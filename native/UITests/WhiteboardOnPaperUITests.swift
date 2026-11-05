//  Stories 590–612 on the simulator, its ghosts in `WhiteboardPaperGhostsUITests`: a new board on paper is a real board behind a switch, and the old canvas is left
//  alone. How the Pencil feels and what a finger does with one paired are the iPad's (`whiteboard` action: paper_touch).
//  A finger draws on the simulator.

import XCTest

final class WhiteboardOnPaperUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// The switch is remembered, so every test leaves it off for the tests after it.
  override func tearDown() {
    let app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "off"])
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 20))
    app.terminate()
  }

  private func launch(_ environment: [String: String] = [:]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    for (key, value) in environment { app.launchEnvironment[key] = value }
    app.launch()
    return app
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
    waitForExpectations(timeout: timeout)
  }

  private func keep(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  private func newBoard(_ app: XCUIApplication) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 20), app.debugDescription)
    new.tap()
    XCTAssertTrue(app.buttons["whiteboard-send"].waitForExistence(timeout: 10), app.debugDescription)
  }

  /// By its words: the board's screen gives its own id to what's inside it.
  private func pageNumber(_ app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch
  }

  private func copyError(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Copy error'")).firstMatch
  }

  /// A board on the old canvas, drawn here: any other row is a board on paper or another device's.
  private func oldRow(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "NOT (label CONTAINS 'On paper') AND NOT (label CONTAINS 'Drawn on')")).firstMatch
  }

  private func row(_ app: XCUIApplication, _ text: String) -> XCUIElement {
    app.buttons.matching(identifier: "whiteboard-card").matching(NSPredicate(format: "label CONTAINS %@", text))
      .firstMatch
  }

  /// Stories 590–593, 597, 598, 602, 603, 651: the switch, the board, what it doesn't offer, and its ink through a relaunch.
  func testANewBoardIsOnPaperUntilTheSwitchIsTurnedOff() {
    var app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "untouched"])
    let options = app.buttons["whiteboard-options"]
    XCTAssertTrue(options.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertEqual(options.label, "Board options, new boards on paper", "on until it's turned off")
    options.tap()
    let toggle = app.descendants(matching: .any)["New boards on paper"].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
    toggle.tap()
    waitFor(options, label: "Board options, new boards on the old canvas")
    app.terminate()
    app = launch()
    let remembered = app.buttons["whiteboard-options"]
    XCTAssertTrue(remembered.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertEqual(remembered.label, "Board options, new boards on the old canvas", "turning it off is remembered")

    // Story 602: turned back on from the menu, the next board is on paper.
    remembered.tap()
    XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
    toggle.tap()
    waitFor(remembered, label: "Board options, new boards on paper")
    newBoard(app)
    XCTAssertTrue(pageNumber(app).waitForExistence(timeout: 10), app.debugDescription)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 10), app.debugDescription)
    app.terminate()

    app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "untouched"])
    newBoard(app)
    let page = pageNumber(app)
    XCTAssertTrue(page.waitForExistence(timeout: 10), app.debugDescription)
    waitFor(page, label: "Page 1 of 1")
    XCTAssertTrue(app.buttons["whiteboard-board"].exists, "the colours are still there")
    sleep(2)
    keep(app, "a new board on paper")

    let send = app.buttons["whiteboard-send"]
    stroke(app, atHeight: 0.3)
    waitFor(send, label: "Send to Larry, 1 strokes")
    waitFor(page, label: "Page 1 of 2")
    keep(app, "ink brings the next page")

    // Story 597.
    let colours = app.buttons["whiteboard-board"]
    colours.tap()
    let sage = app.descendants(matching: .any)["Sage"].firstMatch
    XCTAssertTrue(sage.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(app.descendants(matching: .any)["Grid lines"].exists, "story 652: the grid")
    XCTAssertTrue(app.descendants(matching: .any)["Ruled lines"].exists, "story 434: ruled lines")
    sage.tap()
    waitFor(colours, label: "Board, Sage")
    sleep(1)
    keep(app, "the paper in sage")
    sleep(1)  // Past the second the board waits before it saves, and it's the save that's being looked at.

    // Killed, not closed: what's on the board is what the save wrote a moment after the stroke.
    app.terminate()
    app = launch()
    let saved = row(app, "On paper")
    XCTAssertTrue(saved.waitForExistence(timeout: 20), app.debugDescription)
    saved.tap()
    XCTAssertTrue(send.waitForExistence(timeout: 10), app.debugDescription)
    waitFor(send, label: "Send to Larry, 1 strokes")
    waitFor(page, label: "Page 1 of 2")
    keep(app, "the same ink after a relaunch")

    // Story 603: another stroke, and it stays where it was drawn.
    sleep(1)
    stroke(app, atHeight: 0.4)
    waitFor(send, label: "Send to Larry, 2 strokes")
  }

  /// Stories 595, 607, 651: the switch moves no board, either way, and with it off a new board is on the old canvas.
  func testTheSwitchMovesNoBoard() {
    // An old board, then the switch on: it still opens on the old canvas.
    var app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "off"])
    newBoard(app)
    XCTAssertTrue(app.buttons["whiteboard-send"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(pageNumber(app).exists, "the old canvas")
    sleep(1)
    stroke(app, atHeight: 0.5)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 1 strokes")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(oldRow(app).waitForExistence(timeout: 10), app.debugDescription)
    app.terminate()

    app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "on"])
    XCTAssertTrue(oldRow(app).waitForExistence(timeout: 20), app.debugDescription)
    oldRow(app).tap()
    XCTAssertTrue(app.buttons["whiteboard-send"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(pageNumber(app).exists)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // A board on paper, then the switch off: it stays on paper.
    newBoard(app)
    sleep(2)
    stroke(app, atHeight: 0.3)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 1 strokes")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let paper = row(app, "On paper")
    XCTAssertTrue(paper.waitForExistence(timeout: 10), app.debugDescription)
    app.terminate()

    app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "off"])
    XCTAssertTrue(paper.waitForExistence(timeout: 20), app.debugDescription)
    paper.tap()
    XCTAssertTrue(pageNumber(app).waitForExistence(timeout: 10), app.debugDescription)
  }

  /// Story 609: in dark mode new ink can be seen. PaperKit left to itself draws it black on black. Read off the screenshot:
  /// the canvas isn't in the accessibility tree.
  func testInkShowsInDarkMode() throws {
    let mode = XCUIDevice.shared.appearance
    addTeardownBlock { XCUIDevice.shared.appearance = mode }
    XCUIDevice.shared.appearance = .dark
    let app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "on"])
    newBoard(app)
    sleep(2)
    // The first stroke brings page 2, and on a phone that moves the view: the second is the one that stays put.
    stroke(app, atHeight: 0.3)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 1 strokes")
    sleep(1)
    stroke(app, atHeight: 0.5)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 2 strokes")
    sleep(1)
    let shot = app.screenshot()
    keep(app, "ink in dark mode")
    let image = try XCTUnwrap(shot.image.cgImage)
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: 1, height: 200, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    // One pixel wide and 200 tall, through the middle of the stroke, from the screen's own pixels.
    let (x, y) = (CGFloat(image.width) * 0.45, CGFloat(image.height) * 0.5)
    let strip = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y - 100, width: 1, height: 200)))
    context.draw(strip, in: CGRect(x: 0, y: 0, width: 1, height: 200))
    let data = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: 800)
    let brightness = (0..<200).map { Int(data[$0 * 4]) }
    let (lightest, darkest) = (brightness.max() ?? 0, brightness.min() ?? 0)
    XCTAssertGreaterThan(lightest, 200, "the paper is its pale shade")
    XCTAssertLessThan(darkest, 90, "and the ink on it is dark enough to see")

    // The list goes back to the device's mode.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 10), app.debugDescription)
    sleep(2)  // Past the board sliding away, whose screen is still light.
    keep(app, "the list after a board on paper, in dark mode")
    let list = try XCTUnwrap(app.screenshot().image.cgImage)
    let corner = try XCTUnwrap(list.cropping(to: CGRect(x: 4, y: list.height / 2, width: 1, height: 1)))
    context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 200))
    XCTAssertLessThan(Int(data[0]), 60, "the boards list is dark again")
  }

  /// Story 604: a new board on paper closed without a stroke leaves no row.
  func testAnEmptyBoardOnPaperLeavesNoRow() {
    let app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "on"])
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 20), app.debugDescription)
    sleep(1)
    let before = app.buttons.matching(identifier: "whiteboard-card").count
    newBoard(app)
    XCTAssertTrue(pageNumber(app).waitForExistence(timeout: 10), app.debugDescription)
    sleep(1)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 10), app.debugDescription)
    sleep(1)
    XCTAssertEqual(app.buttons.matching(identifier: "whiteboard-card").count, before)
  }

  /// Stories 599, 612: a failed save is a problem that can be copied, on the board, and on the list if he then leaves.
  func testAFailedSaveShowsAndDoesNotVanishOnLeaving() {
    let app = launch([
      "GRABBER_WHITEBOARD_NEW_ON_PAPER": "on", "GRABBER_WHITEBOARD_SAVE_FAILS": "1",
    ])
    newBoard(app)
    sleep(2)
    stroke(app, atHeight: 0.3)
    let copy = copyError(app)
    XCTAssertTrue(copy.waitForExistence(timeout: 10), "on the board" + app.debugDescription)
    keep(app, "a failed save on the board")
    sleep(1)
    stroke(app, atHeight: 0.4)
    sleep(1)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(copy.waitForExistence(timeout: 10), "on the list" + app.debugDescription)
    keep(app, "a failed save on the list")
  }

  /// Story 601: *Try on paper* still opens on a board on paper, and leaves it alone.
  func testTryOnPaperStillWorksOnABoardOnPaper() {
    let app = launch(["GRABBER_WHITEBOARD_NEW_ON_PAPER": "on"])
    newBoard(app)
    sleep(2)
    stroke(app, atHeight: 0.3)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 1 strokes")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let board = row(app, "On paper")
    XCTAssertTrue(board.waitForExistence(timeout: 10), app.debugDescription)
    board.press(forDuration: 1.2)
    let tryIt = app.buttons["Try on paper"]
    XCTAssertTrue(tryIt.waitForExistence(timeout: 5), app.debugDescription)
    tryIt.tap()
    let menu = app.buttons["paper-trial-menu"]
    XCTAssertTrue(menu.waitForExistence(timeout: 15), app.debugDescription)
    waitFor(menu, label: "Trial, 1 strokes")
    keep(app, "the trial, with its test marks")
    app.buttons["paper-trial-close"].tap()
    XCTAssertTrue(board.waitForExistence(timeout: 10), app.debugDescription)
  }
}
