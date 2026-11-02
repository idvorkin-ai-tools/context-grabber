//  Stories 344, 349, 351, 354, 357, 358, 370, 371 and 373 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): a stroke and a pause bring Claude's ghost, Larry's turn brings his marks beside Claude's, Claude's fade and Larry's stay, a kept ghost is ink, the
//  switch stops the asking. A finger draws on the simulator, which is story 354's device. The Pencil is the iPad's check.

import XCTest

final class WhiteboardTurnUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit.
  /// `cockpit` picks how the fake Cockpit answers: "/plain" doesn't stream, "/many" streams six marks.
  private func openBoard(
    keepHook: Bool = false, ghostSeconds: Int? = nil, cockpit way: String = "", say: String? = nil
  ) throws -> (XCUIApplication, XCUIElement) {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit + way
    if keepHook { app.launchEnvironment["GRABBER_WHITEBOARD_KEEP"] = "first" }
    if let say { app.launchEnvironment["GRABBER_WHITEBOARD_SAY"] = say }
    if let ghostSeconds { app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "\(ghostSeconds)" }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.waitForExistence(timeout: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    sleep(1)
    return (app, ghosts)
  }

  /// The canvas is not in the accessibility snapshot: the stroke goes to the window by position, ending at 60% across.
  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat = 0.5) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func wait(_ button: XCUIElement, label: String, timeout: TimeInterval) {
    expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: button)
    waitForExpectations(timeout: timeout)
  }

  /// How many strokes the board holds, from the Send button's label.
  private func wait(_ app: XCUIApplication, strokes: Int) {
    let send = app.buttons["whiteboard-send"]
    expectation(for: NSPredicate(format: "label == %@", "Send to Larry, \(strokes) strokes"), evaluatedWith: send)
    waitForExpectations(timeout: 8)
  }

  func testSpeakingOnAnEmptyBoardBringsAGhostWithoutAStroke() throws {
    let (app, ghosts) = try openBoard(say: "draw a circle")
    app.buttons["whiteboard-mic"].tap()
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    wait(app, strokes: 0)
  }

  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)

    app.buttons["whiteboard-larry"].tap()
    // Larry's two marks beside Claude's one: each author replaces only their own.
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 15)
  }

  func testClaudesGhostsFadeAndLarrysStay() throws {
    let (app, ghosts) = try openBoard(ghostSeconds: 6)
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    app.buttons["whiteboard-larry"].tap()
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 5)
    wait(ghosts, label: "Ghosts on, 2 showing", timeout: 12)
  }

  /// Story 370: the count climbs. XCUI's own predicate waits look once a second, too coarse for marks 400 ms apart, so
  /// this reads the label in a loop and keeps each count it sees.
  func testMarksArriveOneAtATime() throws {
    let (app, ghosts) = try openBoard(cockpit: "/many")
    stroke(app)
    var counts: [Int] = []
    let until = Date().addingTimeInterval(15)
    while counts.last != 6, Date() < until {
      let count = ghosts.label.split(separator: " ").compactMap { Int($0) }.first
      if let count, count != counts.last { counts.append(count) }
    }
    XCTAssertEqual(counts.last, 6, "\(counts)")
    XCTAssertEqual(counts, counts.sorted(), "only ever climbs: \(counts)")
    XCTAssertGreaterThan(counts.count, 1, "seen on the way: \(counts)")
    // What the ghosts look like is for a person to judge: kept with the test's result.
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "ghosts-like-ink"
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Story 373: a Cockpit that answers with one JSON.
  func testACockpitThatDoesNotStreamStillBringsAGhost() throws {
    let (app, ghosts) = try openBoard(cockpit: "/plain")
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
  }

  func testTheKeepHookTurnsTheFirstGhostIntoInk() throws {
    let (app, ghosts) = try openBoard(keepHook: true)
    stroke(app)
    wait(app, strokes: 2)
    XCTAssertEqual(ghosts.label, "Ghosts on")
  }

  /// The fake Cockpit's ghost is a circle whose left edge is 10 points past the drawing's right edge, halfway down it.
  func testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    wait(ghosts, label: "Ghosts on", timeout: 3)
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 1 strokes")

    stroke(app, atHeight: 0.5)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 2 strokes")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0)).tap()
    wait(app, strokes: 3)
    XCTAssertEqual(ghosts.label, "Ghosts on")
  }

  /// A ghost shows in the board's note, found by what it says: an identifier on the note never matched, with the note on
  /// screen. The second stroke shows the same query can see it.
  func testGhostsOffAsksNothing() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    wait(ghosts, label: "Ghosts off", timeout: 3)
    stroke(app)
    wait(app, strokes: 1)
    sleep(4)
    let note = app.staticTexts["1 suggestion: tap one to keep it"]
    XCTAssertFalse(note.exists, note.debugDescription)
    ghosts.tap()
    wait(ghosts, label: "Ghosts on", timeout: 3)
    stroke(app, atHeight: 0.6)
    XCTAssertTrue(note.waitForExistence(timeout: 8), app.debugDescription)
  }
}
