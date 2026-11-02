//  Stories 344, 349, 351, 354, 357, 358, 370, 371, 373, 378, 380–389, 402, 403 and 407 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): a stroke and a pause bring Claude's ghost, Larry's turn hands him the board and his marks arrive by themselves beside Claude's, Claude's fade and Larry's stay, a kept ghost is ink, the
//  switch stops the asking. A finger draws on the simulator, which is story 354's device. The Pencil is the iPad's check.

import XCTest

final class WhiteboardTurnUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit.
  /// `cockpit` picks how the fake Cockpit answers: "/plain" doesn't stream, "/many" streams six marks.
  private func openBoard(
    keepHook: Bool = false, ghostSeconds: Int? = nil, say: String? = nil, cockpit way: String = ""
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

  func testSpeakingWithGhostsOffAsksNothing() throws {
    let (app, ghosts) = try openBoard(say: "draw a square")
    ghosts.tap()
    wait(ghosts, label: "Ghosts off", timeout: 3)
    app.buttons["whiteboard-mic"].tap()
    sleep(4)
    XCTAssertEqual(ghosts.label, "Ghosts off")
  }

  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)

    app.buttons["whiteboard-larry"].tap()
    // Larry's two marks beside Claude's one, with no further tap: each author replaces only their own.
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 15)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .waitForExistence(timeout: 3), app.debugDescription)
  }

  /// The fake Cockpit draws on the board's thread, as Larry does when he has something to add.
  private func larryDraws(_ count: Int, on cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-draws")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"count": \#(count)}"#.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// Back to the list and into the same board.
  private func reopenBoard(_ app: XCUIApplication) {
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons["whiteboard-card"].firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
    card.tap()
    XCTAssertTrue(app.buttons["whiteboard-ghosts"].waitForExistence(timeout: 5), app.debugDescription)
  }

  /// Stories 382, 383, 386 and 388, with Ghosts off so only Larry's marks show. Unprompted marks replace his unkept ones with no
  /// tap, the newest set comes back when the board opens again, and once dismissed it doesn't, on either count.
  func testLarrysMarksArriveOnTheirOwnAndADismissedSetStaysGone() throws {
    let cockpit = try XCTUnwrap(ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"])
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-larry"].tap()
    let marks = { (count: Int) -> NSPredicate in
      NSPredicate(format: "label CONTAINS %@", "\(count) suggestion\(count == 1 ? "" : "s"): tap one to keep it")
    }
    XCTAssertTrue(
      app.staticTexts.matching(marks(2)).firstMatch.waitForExistence(timeout: 15), app.debugDescription)

    try larryDraws(3, on: cockpit)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.waitForExistence(timeout: 10), app.debugDescription)

    reopenBoard(app)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.waitForExistence(timeout: 10), app.debugDescription)

    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    let none = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "tap one to keep it")).firstMatch
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: none)
    waitForExpectations(timeout: 3)
    sleep(4)  // A look at the thread has come and gone.
    XCTAssertFalse(none.exists, app.debugDescription)
    reopenBoard(app)
    sleep(4)
    XCTAssertFalse(none.exists, app.debugDescription)
  }

  func testClaudesGhostsFadeAndLarrysStay() throws {
    let (app, ghosts) = try openBoard(ghostSeconds: 15)
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    app.buttons["whiteboard-larry"].tap()
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 10)
    wait(ghosts, label: "Ghosts on, 2 showing", timeout: 20)
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

  /// The colour of the screen where nothing is drawn, as 0xRRGGBB: the canvas isn't in the accessibility tree.
  private func paperOnScreen() throws -> UInt32 {
    let shot = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage)
    var pixel = [UInt8](repeating: 0, count: 4)
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(
      CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(
      shot,
      in: CGRect(
        x: -CGFloat(shot.width) * 0.85, y: -CGFloat(shot.height) * 0.65, width: CGFloat(shot.width),
        height: CGFloat(shot.height)))
    return UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
  }

  private func keepShot(_ name: String) {
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  private func assertPaper(_ expected: UInt32, _ what: String) throws {
    sleep(1)
    let seen = try paperOnScreen()
    for shift: UInt32 in [16, 8, 0] {
      let channel = { (rgb: UInt32) in Int(rgb >> shift & 0xFF) }
      XCTAssertLessThanOrEqual(
        abs(channel(seen) - channel(expected)), 4, "\(what): saw \(String(seen, radix: 16))")
    }
  }

  /// Stories 378, 402, 403: the colour is on the canvas, follows the mode, and stays when the board opens again.
  func testABoardsColourShowsInBothModesAndStaysWithIt() throws {
    let before = XCUIDevice.shared.appearance
    addTeardownBlock { XCUIDevice.shared.appearance = before }
    XCUIDevice.shared.appearance = .light
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    wait(ghosts, label: "Ghosts off", timeout: 3)
    let paper = app.buttons["whiteboard-board"]
    XCTAssertFalse(app.buttons["OverflowBarButtonItem"].exists, "the top bar has room for all its buttons")
    XCTAssertEqual(paper.label, "Board, Plain")
    try assertPaper(0xFFFFFF, "Plain, light")

    paper.tap()
    let cream = app.buttons["Cream"]
    XCTAssertTrue(cream.waitForExistence(timeout: 5), app.debugDescription)
    keepShot("The menu")
    cream.tap()
    wait(paper, label: "Board, Cream", timeout: 3)
    try assertPaper(0xFBF3DC, "Cream, light")
    XCUIDevice.shared.appearance = .dark
    try assertPaper(0x2B2416, "Cream, dark")
    stroke(app)
    wait(app, strokes: 1)
    keepShot("Ink on Cream, dark, the tool picker back")
    XCUIDevice.shared.appearance = .light

    reopenBoard(app)
    wait(paper, label: "Board, Cream", timeout: 3)
    try assertPaper(0xFBF3DC, "Cream, reopened")
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

  /// Story 407: off until asked, visible when on (read from the pixels: the board isn't in the accessibility tree), gone
  /// when off, and remembered by this board and no other. Ghosts off, so nothing else moves on the board.
  func testTheGridShowsWhenAskedAndStaysWithItsBoard() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    wait(ghosts, label: "Ghosts off", timeout: 3)
    stroke(app)
    wait(app, strokes: 1)
    let view = app.buttons["whiteboard-board"]
    XCTAssertEqual(view.label, "Board, Plain")
    sleep(1)
    let off = app.screenshot().image

    tapGrid(app, view, expect: "Board, Plain, grid on")
    sleep(1)
    let on = app.screenshot()
    try? on.pngRepresentation.write(to: URL(fileURLWithPath: "/Users/idvorkin/tmp/agent/notes/wb/grid-on.png"))  // TEMP
    let picture = XCTAttachment(screenshot: on)
    picture.name = "grid-on"
    picture.lifetime = .keepAlways
    add(picture)
    XCTAssertGreaterThan(boardPixelsDiffering(off, on.image), 1000, "no grid lines appeared")

    reopenBoard(app)
    XCTAssertEqual(view.label, "Board, Plain, grid on")
    tapGrid(app, view, expect: "Board, Plain")
    reopenBoard(app)
    XCTAssertEqual(view.label, "Board, Plain")
    tapGrid(app, view, expect: "Board, Plain, grid on")

    // A new board has its own switch.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.waitForExistence(timeout: 5), app.debugDescription)
    new.tap()
    XCTAssertTrue(view.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(view.label, "Board, Plain")
  }

  /// The grid's switch, in the Board menu.
  private func tapGrid(_ app: XCUIApplication, _ view: XCUIElement, expect: String) {
    view.tap()
    let item = app.descendants(matching: .any)["Grid lines"].firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 3), app.debugDescription)
    item.tap()
    wait(view, label: expect, timeout: 3)
  }

  /// How many pixels differ in the middle of the screen, clear of the bars and the tool picker.
  private func boardPixelsDiffering(_ a: UIImage, _ b: UIImage) -> Int {
    func pixels(_ image: UIImage) -> [UInt8] {
      let cg = image.cgImage!
      let width = cg.width
      let height = cg.height / 2
      var bytes = [UInt8](repeating: 0, count: width * height * 4)
      bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: -cg.height / 4, width: width, height: cg.height))
      }
      return bytes
    }
    let (x, y) = (pixels(a), pixels(b))
    var differing = 0
    for i in stride(from: 0, to: min(x.count, y.count), by: 4) {
      let channels = (0..<3).map { abs(Int(x[i + $0]) - Int(y[i + $0])) }
      if channels.contains(where: { $0 > 2 }) { differing += 1 }
    }
    return differing
  }
}
