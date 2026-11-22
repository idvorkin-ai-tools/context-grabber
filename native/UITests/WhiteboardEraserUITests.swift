//  Story 1098 (#1078, bead context-grabber-8o93) on the iPad simulator: the eraser picked by a tap in the board's real
//  tool picker, then a stroke. The picker opens on the tool picked last, in an earlier launch too, and the board has to
//  erase with it from the first stroke; before the fix that stroke drew black ink with the eraser showing selected. A
//  finger stands in for the Pencil (fingers draw on the simulator). Each test leaves the pen picked, as the other board
//  tests expect.

import XCTest

final class WhiteboardEraserUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  /// A new board with Ghosts off; the pen picked first unless the test wants the picker as the last launch left it.
  private func openBoard(pickPen: Bool = true) -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if pickPen { pen.tap() }
    sleep(1)
    return app
  }

  private func strokes(_ app: XCUIApplication, _ count: Int) {
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, \(count) strokes"), app.buttons["whiteboard-send"], timeout: 10
    )
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// The eraser picked in one launch is still picked in the next, and the first stroke there erases: no ink lands.
  func testAnEraserKeptFromTheLastLaunchErasesFromTheFirstStroke() {
    let first = openBoard()
    first.buttons["Eraser"].tap()
    sleep(1)
    first.terminate()
    let app = openBoard(pickPen: false)
    XCTAssertTrue(app.buttons["Eraser"].isSelected, "the picker opens on the eraser picked last launch")
    point(app, 0.20, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.35))
    sleep(2)
    shot(app, "the eraser kept from the last launch, after a stroke")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 0 strokes", "the eraser drew no ink")
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "nothing on the sheet")
    // A pick after that still reaches the board: the pen draws.
    app.buttons["Pen"].tap()
    sleep(1)
    point(app, 0.20, 0.50).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.50))
    strokes(app, 1)
  }

  /// The eraser picked by a tap draws no ink, after BugKit's report sheet too (the iPad session of #1078 had one open
  /// just before). On bare paper, so any ink on the sheet is the eraser's.
  func testThePickedEraserDrawsNoInkAfterTheReportSheet() {
    let app = openBoard()
    app.buttons["whiteboard-feedback"].tapWhenSettled()
    let sheet = app.navigationBars["Report a problem"]
    XCTAssertTrue(sheet.appears(within: 10), app.debugDescription)
    sheet.buttons["Cancel"].tap()
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
    waitForExpectations(timeout: 10)
    app.buttons["Eraser"].tap()
    sleep(1)
    point(app, 0.20, 0.35).press(forDuration: 0.05, thenDragTo: point(app, 0.45, 0.35))
    sleep(2)
    shot(app, "the eraser after the report sheet, after a stroke")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 0 strokes", "the eraser drew no ink")
    XCTAssertNil(PaperScreen.settled(app) { $0.ink }, "nothing on the sheet")
    app.buttons["Pen"].tap()
  }
}
