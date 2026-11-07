//  Stories 344, 345, 349, 354, 357, 360, 367, 371, 378, 380–389, 402, 403 and 407–410 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): a stroke and a pause bring Claude's ghost through a streamed answer, Larry's turn hands him the board and his marks arrive by themselves beside Claude's, a kept ghost is ink.
//  A finger draws on the simulator, which is story 354's device. The Pencil is the iPad's check. `WhiteboardTurnOnPaperUITests` runs these on a board on paper.
//  The turn's rules (Claude's fade, the count climbing, a Cockpit that doesn't stream, Ghosts off, stale answers, spoken words held) are `WhiteboardGhostTurnsTests`, on the host.

import XCTest

class WhiteboardTurnUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// What else the app is started with: a subclass runs these on a board on paper.
  var boardEnvironment: [String: String] { [:] }

  /// The fake Cockpit's ghost is a circle whose left edge is 10 points past the drawing's right edge, halfway down it, and a
  /// finger's stroke ends at 60% across.
  func tapOnTheGhost(_ app: XCUIApplication) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0)).tap()
  }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit, which streams one mark.
  private func openBoard(keepHook: Bool = false, say: String? = nil) throws -> (XCUIApplication, XCUIElement) {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "off"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    if keepHook { app.launchEnvironment["GRABBER_WHITEBOARD_KEEP"] = "first" }
    if let say { app.launchEnvironment["GRABBER_WHITEBOARD_SAY"] = say }
    for (key, value) in boardEnvironment { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
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
    waitUntil(NSPredicate(format: "label == %@", label), button, timeout: timeout)
  }

  /// How many strokes the board holds, from the Send button's label.
  private func wait(_ app: XCUIApplication, strokes: Int) {
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, \(strokes) strokes"), app.buttons["whiteboard-send"],
      timeout: 8)
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

  /// The one path from a streamed answer to a ghost on screen (story 370's reading is `WhiteboardGhostTurnsTests`).
  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)

    app.buttons["whiteboard-larry"].tap()
    // Larry's two marks beside Claude's one, with no further tap: each author replaces only their own.
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 15)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 3), app.debugDescription)
    // Story 371: what the ghosts look like, Claude's and Larry's, is for a person to judge: kept with the test's result.
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "ghosts-like-ink"
    picture.lifetime = .keepAlways
    add(picture)
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
    XCTAssertTrue(card.appears(within: 5), app.debugDescription)
    card.tap()
    XCTAssertTrue(app.buttons["whiteboard-ghosts"].appears(within: 5), app.debugDescription)
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
      app.staticTexts.matching(marks(2)).firstMatch.appears(within: 15), app.debugDescription)

    try larryDraws(3, on: cockpit)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.appears(within: 10), app.debugDescription)

    reopenBoard(app)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.appears(within: 10), app.debugDescription)

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

  func testTheKeepHookTurnsTheFirstGhostIntoInk() throws {
    let (app, ghosts) = try openBoard(keepHook: true)
    stroke(app)
    wait(app, strokes: 2)
    XCTAssertEqual(ghosts.label, "Ghosts on")
  }

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
    sleep(1)  // Past the ghost drawing in.
    tapOnTheGhost(app)
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

  /// Cream's deep shade: a board on paper stays in its pale one.
  var creamInDarkMode: UInt32 { 0x2B2416 }

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
    XCTAssertTrue(cream.appears(within: 5), app.debugDescription)
    keepShot("The menu")
    cream.tapWhenSettled()
    wait(paper, label: "Board, Cream", timeout: 3)
    try assertPaper(0xFBF3DC, "Cream, light")
    XCUIDevice.shared.appearance = .dark
    try assertPaper(creamInDarkMode, "Cream, dark")
    stroke(app)
    wait(app, strokes: 1)
    keepShot("Ink on Cream, dark, the tool picker back")
    XCUIDevice.shared.appearance = .light

    reopenBoard(app)
    wait(paper, label: "Board, Cream", timeout: 3)
    try assertPaper(0xFBF3DC, "Cream, reopened")
  }

  /// Stories 407–410: off until asked, visible when on and gone when off (read from the pixels: the board isn't in the
  /// accessibility tree), and remembered by this board and no other. Ghosts off, so nothing else moves on the board. A
  /// reopened board frames its drawing differently, so its pixels are compared with themselves.
  func testTheGridShowsWhenAskedAndStaysWithItsBoard() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    wait(ghosts, label: "Ghosts off", timeout: 3)
    stroke(app)
    wait(app, strokes: 1)
    let board = app.buttons["whiteboard-board"]
    XCTAssertEqual(board.label, "Board, Plain")
    let off = settledScreen(app)

    tapGrid(app, board, expect: "Board, Plain, grid on")
    let on = settledScreen(app)
    let picture = XCTAttachment(image: on)
    picture.name = "grid-on"
    picture.lifetime = .keepAlways
    add(picture)
    XCTAssertGreaterThan(boardPixelsDiffering(off, on), Self.gridPixels, "no grid lines appeared")

    tapGrid(app, board, expect: "Board, Plain")
    XCTAssertLessThan(boardPixelsDiffering(off, settledScreen(app)), Self.noPixels, "the lines stayed")

    // Left on: it opens on, and it draws them.
    tapGrid(app, board, expect: "Board, Plain, grid on")
    reopenBoard(app)
    XCTAssertEqual(board.label, "Board, Plain, grid on")
    let reopenedOn = settledScreen(app)
    tapGrid(app, board, expect: "Board, Plain")
    let reopenedOff = settledScreen(app)
    XCTAssertGreaterThan(
      boardPixelsDiffering(reopenedOn, reopenedOff), Self.gridPixels, "the reopened board drew no lines")

    // Left off: it opens off, and draws none.
    reopenBoard(app)
    XCTAssertEqual(board.label, "Board, Plain")
    XCTAssertLessThan(boardPixelsDiffering(reopenedOff, settledScreen(app)), Self.noPixels, "off, and lines showed")

    // A new board has its own switch.
    tapGrid(app, board, expect: "Board, Plain, grid on")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 5), app.debugDescription)
    new.tap()
    XCTAssertTrue(board.appears(within: 5), app.debugDescription)
    XCTAssertEqual(board.label, "Board, Plain")
  }

  private static let gridPixels = 1000
  private static let noPixels = 50

  private func settledScreen(_ app: XCUIApplication) -> UIImage {
    sleep(1)
    return app.screenshot().image
  }

  /// The grid's switch, in the Board menu.
  private func tapGrid(_ app: XCUIApplication, _ view: XCUIElement, expect: String) {
    view.tap()
    let item = app.descendants(matching: .any)["Grid lines"].firstMatch
    XCTAssertTrue(item.appears(within: 3), app.debugDescription)
    item.tapWhenSettled()
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
