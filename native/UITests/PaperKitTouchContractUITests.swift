//  Story 1020 (bead 8o93): the touch contracts on real PaperKit, the half of story 1019's that needs a real touch. Each
//  test launches the bare PaperKit stage (`GRABBER_PAPER_STAGE`, the board's feature set and its touch watcher, none of
//  its handling) and touches it with a finger, as XCUITest's touches are on the simulator, reading what PaperKit did off
//  the stage's state line. Each names the board's code that rests on it. When one fails, the platform moved: read what
//  the board does with that behaviour before changing the test. `just native-test-contracts` runs them, with no retry.

import XCTest

final class PaperKitTouchContractUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func launch(_ stage: String) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_PAPER_STAGE"] = stage
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    app.launch()
    XCTAssertTrue(state(app).appears(within: 20), app.debugDescription)
    return app
  }

  private func state(_ app: XCUIApplication) -> XCUIElement { app.staticTexts["paper-stage-state"] }

  /// The stage's state line, `key=value;...`, as a dictionary.
  private func read(_ app: XCUIApplication) -> [String: String] {
    var out: [String: String] = [:]
    for part in state(app).label.split(separator: ";") {
      let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
      out[pair[0]] = pair.count > 1 ? pair[1] : ""
    }
    return out
  }

  /// Until the state line says `key=value`.
  private func waitFor(_ app: XCUIApplication, _ key: String, _ value: String, timeout: TimeInterval = 5) {
    waitUntil(NSPredicate(format: "label CONTAINS %@", "\(key)=\(value);"), state(app), timeout: timeout)
  }

  private func spot(_ app: XCUIApplication, _ dx: CGFloat, _ dy: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy))
  }

  /// A short finger stroke across the paper.
  private func stroke(_ app: XCUIApplication, hold: TimeInterval = 0.05) {
    spot(app, 0.3, 0.5).press(forDuration: hold, thenDragTo: spot(app, 0.6, 0.5))
  }

  /// #965 (stories 1008, 1009): a finger's stroke is one step on PaperKit's undo stack, named *Add Strokes*, the name the
  /// bar's Undo reads as plain *Undo* (`BoardUndoButtons.unnamed`). And #1105: the lift of a stroke PaperKit drew
  /// reaches the board's touch watcher as ended, its touch's phase ended (the fold erase takes a fold only on that).
  func testAFingerStrokeIsOneUndoStepNamedAddStrokesAndItsLiftEnds() {
    let app = launch("draw")
    stroke(app)
    waitFor(app, "strokes", "1")
    waitFor(app, "ended", "1")
    let seen = read(app)
    XCTAssertEqual(seen["undo"], "Add Strokes", "PaperKit's name for a drawn stroke's step: \(seen)")
    XCTAssertEqual(seen["can_undo"], "1", "\(seen)")
    XCTAssertEqual(seen["cancelled"], "0", "PaperKit's drawing calls off no touch the watcher sees: \(seen)")
    XCTAssertEqual(seen["lift"], "ended", "\(seen)")
    app.buttons["paper-stage-undo"].tap()
    waitFor(app, "strokes", "0")
  }

  /// #1105 (story 903's fold erase): a touch the system calls off while it is down reaches the watcher as cancelled, its
  /// phase cancelled, never as ended: the fold erase reads `touch.phase == .cancelled` to take no fold by its marker.
  func testATouchCalledOffReachesTheWatcherCancelled() {
    let app = launch("draw,cancel")
    stroke(app, hold: 1.0)
    waitFor(app, "called_off", "1")
    waitFor(app, "cancelled", "1")
    let seen = read(app)
    XCTAssertEqual(seen["ended"], "0", "a called-off touch never also ends: \(seen)")
    XCTAssertEqual(seen["lift"], "cancelled", "\(seen)")
  }

  /// #883 (stories 616, 825): with a finger set to select, as the board sets it while marks show, a finger tap draws
  /// nothing at the tap, PaperKit draws a dot there all the same a few tenths of a second after the lift, and its own
  /// undo takes the dot back. The board's `takesBackTapDot` rests on all three.
  func testAFingerTapThatSelectsStillGetsADotThatPaperKitsUndoTakesBack() {
    let app = launch("select")
    spot(app, 0.5, 0.5).tap()
    waitFor(app, "ended", "1")
    waitFor(app, "strokes", "1", timeout: 3)
    let seen = read(app)
    XCTAssertEqual(seen["can_undo"], "1", "the dot is a step PaperKit's undo can take: \(seen)")
    app.buttons["paper-stage-undo"].tap()
    waitFor(app, "strokes", "0")
  }
}
