//  Stories 613–626 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): what paper
//  adds to the ghost turns. `WhiteboardTurnOnPaperUITests` runs the old canvas's own tests on a board on paper, as they're the
//  requirement. A finger draws on the simulator; the Pencil and what a finger does with one paired are the iPad's. The
//  board isn't in the accessibility tree, so where ghosts and ink sit is read from the screen's pixels.

import XCTest

/// `WhiteboardTurnUITests`, every one, on a board on paper.
final class WhiteboardTurnOnPaperUITests: WhiteboardTurnUITests {
  override var boardEnvironment: [String: String] { ["GRABBER_WHITEBOARD_NEW_ON_PAPER": "on"] }

  /// The switch is remembered, so it's left off for the tests after these.
  override func tearDown() {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "off"
    app.launch()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 20))
    app.terminate()
  }

  /// A page's width on a phone is about half a point to the point, so where a ghost lands is read off the screen.
  override func tapOnTheGhost(_ app: XCUIApplication) {
    guard let ghost = PaperScreen(app).orange else {
      XCTFail("no orange on screen")
      return
    }
    PaperScreen.tap(app, ghost.center)
  }

  override func testABoardsColourShowsInBothModesAndStaysWithIt() throws {
    throw XCTSkip("A board on paper is always light for now, and `WhiteboardOnPaperUITests` covers its colour")
  }

  override func testTheGridShowsWhenAskedAndStaysWithItsBoard() throws {
    throw XCTSkip("The grid comes to paper in a later step")
  }
}

/// What's on the screen, by colour, as parts of the window (0...1), between the bars.
struct PaperScreen {
  struct Box {
    var minX: CGFloat
    var minY: CGFloat
    var maxX: CGFloat
    var maxY: CGFloat
    var center: CGPoint { CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
    var width: CGFloat { maxX - minX }
  }

  private let width: Int
  private let height: Int
  private let bytes: [UInt8]

  init(_ app: XCUIApplication) {
    let image = app.screenshot().image.cgImage!
    width = image.width
    height = image.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let (w, h) = (width, height)
    buffer.withUnsafeMutableBytes { raw in
      let context = CGContext(
        data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    bytes = buffer
  }

  private func box(_ matches: (Int, Int, Int) -> Bool) -> Box? {
    var found: Box?
    // Clear of the bars and the page number above, and the tool picker below.
    for y in stride(from: height / 5, to: height * 3 / 4, by: 2) {
      for x in stride(from: 0, to: width, by: 2) {
        let i = (y * width + x) * 4
        guard matches(Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2])) else { continue }
        let (nx, ny) = (CGFloat(x) / CGFloat(width), CGFloat(y) / CGFloat(height))
        if var seen = found {
          seen.minX = min(seen.minX, nx)
          seen.maxX = max(seen.maxX, nx)
          seen.minY = min(seen.minY, ny)
          seen.maxY = max(seen.maxY, ny)
          found = seen
        } else {
          found = Box(minX: nx, minY: ny, maxX: nx, maxY: ny)
        }
      }
    }
    return found
  }

  /// A faint ghost of Claude's on pale paper, or a kept one at full strength.
  var orange: Box? { box { r, g, b in r > 225 && g > 120 && g < 225 && b < 170 && r - b > 80 } }
  /// Only a faint one.
  var ghost: Box? { box { r, g, b in r > 240 && g > 180 && g < 225 && b > 90 && b < 170 } }
  /// A kept one.
  var kept: Box? { box { r, g, b in r > 225 && g > 120 && g < 175 && b < 60 } }
  /// Black ink.
  var ink: Box? { box { r, g, b in r < 70 && g < 70 && b < 70 } }

  static func tap(_ app: XCUIApplication, _ at: CGPoint) {
    app.coordinate(withNormalizedOffset: CGVector(dx: at.x, dy: at.y)).tap()
  }
}

final class WhiteboardPaperGhostsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "off"
    app.launch()
    XCTAssertTrue(app.buttons["whiteboard-new"].waitForExistence(timeout: 20))
    app.terminate()
  }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, Ghosts on, that doesn't fade while a test looks at it.
  private func openBoard(way: String = "", _ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit() + way
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "on"
    app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "600"
    for (key, value) in extra { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.waitForExistence(timeout: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    sleep(2)
    return app
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat = 0.5) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
    waitForExpectations(timeout: timeout)
  }

  private func ghosts(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-ghosts"] }
  private func send(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-send"] }
  private func strokes(_ count: Int) -> String { "Send to Larry, \(count) strokes" }

  private func pageNumber(_ app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// A stroke and the ghost that answers it, settled.
  private func strokeBringsAGhost(_ app: XCUIApplication) -> PaperScreen.Box? {
    stroke(app)
    wait(ghosts(app), label: "Ghosts on, 1 showing", timeout: 10)
    sleep(1)  // Past the note arriving above the board and the ghost drawing in.
    return PaperScreen(app).ghost
  }

  /// Stories 613, 614, 615: the bar, a ghost that can be seen, and a tap on it that makes it ink of its colour.
  func testAGhostShowsOnThePaperAndATapKeepsIt() throws {
    let app = try openBoard()
    for id in ["whiteboard-ghosts", "whiteboard-mic", "whiteboard-larry", "whiteboard-send"] {
      XCTAssertTrue(app.buttons[id].exists, id)
    }
    XCTAssertFalse(app.buttons["whiteboard-paste"].exists, "paste comes in a later step")
    let ghost = try XCTUnwrap(strokeBringsAGhost(app), "a faint orange ghost on screen")
    shot(app, "a ghost on paper")
    XCTAssertEqual(send(app).label, strokes(1), "a ghost isn't ink")

    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    wait(ghosts(app), label: "Ghosts on")
    sleep(1)
    shot(app, "kept")
    let kept = try XCTUnwrap(PaperScreen(app).kept, "ink in Claude's orange")
    XCTAssertEqual(kept.center.x, ghost.center.x, accuracy: 0.03, "where the ghost was")
    XCTAssertEqual(kept.center.y, ghost.center.y, accuracy: 0.05, "where the ghost was")
  }

  /// Story 616: a tap off the ghosts dismisses them and leaves no dot, and then a finger draws again.
  func testATapOffDismissesLeavesNoDotAndAFingerDrawsAgain() throws {
    let app = try openBoard()
    _ = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, CGPoint(x: 0.1, y: 0.72))
    wait(ghosts(app), label: "Ghosts on")
    sleep(1)
    XCTAssertEqual(send(app).label, strokes(1), "no dot")
    stroke(app, atHeight: 0.4)
    wait(send(app), label: strokes(2))
  }

  /// Story 614: pinched and moved, the ghost stays beside the ink, by the screen's own pixels. The same check on a sheet
  /// placed by hand would show any lag only while it moved, which is the iPad's (`paper_touch`'s ghost_slip).
  func testAGhostStaysOnTheInkWhenTheBoardMoves() throws {
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    let ink = try XCTUnwrap(PaperScreen(app).ink, "black ink on screen")
    let gap = (ghost.center.x - ink.center.x) / ink.width
    shot(app, "before")

    app.pinch(withScale: 1.6, velocity: 2)
    sleep(2)
    shot(app, "zoomed in")
    let (ghostZoomed, inkZoomed) = (PaperScreen(app).ghost, PaperScreen(app).ink)
    let bigGhost = try XCTUnwrap(ghostZoomed, "the ghost is still on screen")
    let bigInk = try XCTUnwrap(inkZoomed, "and the ink")
    XCTAssertGreaterThan(bigInk.width, ink.width * 1.2, "the board zoomed")
    XCTAssertEqual((bigGhost.center.x - bigInk.center.x) / bigInk.width, gap, accuracy: 0.1, "the ghost zoomed with the ink")
    XCTAssertEqual(ghosts(app).label, "Ghosts on, 1 showing")
    XCTAssertEqual(send(app).label, strokes(1), "a pinch isn't a stroke")
  }

  /// Story 617: a kept ghost goes with one undo and comes back with one redo, and the undo after that takes his stroke,
  /// which is PaperKit's own step. A hook presses them, as a phone's tool picker has no Undo and keys reach only a run's
  /// first test.
  func testOneUndoTakesAKeptMarkBack() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_KEEP": "4,undo,redo,undo,undo"])
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    shot(app, "kept")
    wait(send(app), label: strokes(1))
    XCTAssertNil(PaperScreen(app).kept, "the orange ink went")
    XCTAssertNotNil(PaperScreen(app).ink, "and his stroke stayed")
    shot(app, "after one undo")
    wait(send(app), label: strokes(2))
    XCTAssertNotNil(PaperScreen(app).kept, "redo brings it back")
    wait(send(app), label: strokes(1))
    wait(send(app), label: strokes(0))
    XCTAssertNil(PaperScreen(app).ink, "the next undo took his stroke")
    shot(app, "after his stroke too")
  }

  /// Stories 617, 618: a mark kept far down brings its pages in the one change, and one undo takes both. The fake's `/far`
  /// answers with a circle well below the last page: a hook keeps it, as it can't be reached to tap.
  func testAMarkKeptPastTheLastPageBringsItsPagesInOneUndo() throws {
    let app = try openBoard(way: "/far", ["GRABBER_WHITEBOARD_KEEP": "first", "GRABBER_WHITEBOARD_AFTER_KEEP": "5,undo"])
    stroke(app)
    wait(send(app), label: strokes(2), timeout: 12)
    wait(pageNumber(app), label: "Page 1 of 6")
    shot(app, "the kept mark's pages")
    wait(send(app), label: strokes(1))
    wait(pageNumber(app), label: "Page 1 of 2")
  }

  /// Story 619: the strokes keep their names, sent, closed, opened and sent again, the kept mark too. Larry's turn sends
  /// them to the fake Cockpit, which says what it got.
  func testAKeptMarkKeepsItsNameThroughAReopen() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    let before = try sends(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    let first = try strokeIDs(cockpit, after: before)
    XCTAssertEqual(first.count, 2, "\(first)")

    sleep(2)  // Past the save.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
    card.tap()
    wait(send(app), label: strokes(2))
    let larry = app.buttons["whiteboard-larry"]
    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: larry)
    waitForExpectations(timeout: 10)
    let middle = try sends(cockpit).count
    larry.tap()
    let second = try strokeIDs(cockpit, after: middle)
    XCTAssertEqual(second, first, "the same names after coming back from the file")
  }

  /// Stories 620, 621: Larry's turn, his marks on the board in his colour, the kept one saved. Ghost text is on
  /// `WhiteboardTurnOnPaperUITests`; here, that it can be seen and kept, and that a ghost left showing isn't saved.
  func testAGhostLeftShowingIsNotSaved() throws {
    let app = try openBoard()
    _ = try XCTUnwrap(strokeBringsAGhost(app))
    sleep(2)  // Past the save.
    app.terminate()
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "on"
    app.launch()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
    card.tap()
    wait(send(app), label: strokes(1))
  }

  private func sends(_ cockpit: String) throws -> [[String]] {
    let url = try XCTUnwrap(URL(string: cockpit + "/fake/strokes"))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["sends"] as? [[String]])
  }

  /// The ids of the send after the first `count`, when it comes.
  private func strokeIDs(_ cockpit: String, after count: Int) throws -> [String] {
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      let all = try sends(cockpit)
      if all.count > count { return all[count] }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("no strokes reached the fake Cockpit")
    return []
  }
}
