//  Stories 853, 855, 858, 900, 901, 1179 on the simulator, against the fake Cockpit
//  (scripts/native/test-whiteboard-ui.sh starts it): a paste's Delete, a margin tap that makes a header and folds it,
//  a fold's lines beside it, Larry's picture of a folded section (#1013), the hold menu, and a header made or unmade
//  as one Undo (bead context-grabber-ssl).
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

  /// Story 1179 (bead context-grabber-ssl): a margin tap's header is one Undo, named for it, that takes back the header
  /// and no stroke; Redo makes it again.
  func testAMarginTapsHeaderIsOneUndoThatLeavesTheInk() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.2, to: 0.5, y: 0.36)
    wait(send(app), label: strokes(2))
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "a ▾ in the margin: \(app.debugDescription)")
    let undo = app.buttons["whiteboard-undo"]
    let redo = app.buttons["whiteboard-redo"]
    waitUntil(NSPredicate(format: "label CONTAINS %@", "Make header"), undo, timeout: 5)
    undo.tap()
    waitUntil(NSPredicate(format: "count == 0"), marks(app, "Header"), timeout: 5)
    wait(send(app), label: strokes(2))
    shot(app, "the header undone, the ink kept")
    waitUntil(NSPredicate(format: "isEnabled == true"), redo, timeout: 5)
    redo.tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "Redo makes it again")
    wait(send(app), label: strokes(2))
  }

  /// Story 1179 (bead context-grabber-ssl): *Not a header* on a folded header opens its lines and unmakes it, one Undo
  /// that puts the header back folded, never the lines hidden with no header to open them.
  func testNotAHeaderOnAFoldIsOneUndoThatPutsTheFoldBack() throws {
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.2, to: 0.5, y: 0.36)
    wait(send(app), label: strokes(2))
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), app.debugDescription)
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), app.debugDescription)
    point(app, 0.7, 0.30).press(forDuration: 1.0)
    let not = app.buttons["whiteboard-hold-not-header"]
    XCTAssertTrue(not.appears(within: 5), "beside a header: Not a header \(app.debugDescription)")
    not.tap()
    waitUntil(NSPredicate(format: "count == 0"), marks(app, "Folded header"), timeout: 5)
    XCTAssertEqual(marks(app, "Header").count, 0, "no header left")
    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "label CONTAINS %@", "Not a header"), undo, timeout: 5)
    undo.tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), "folded again: \(app.debugDescription)")
    shot(app, "Not a header undone: the fold back")
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

  /// A # of four short straight drags, `size` screen points each way, its top left at the screen fractions (`x`, `y`).
  private func hash(_ app: XCUIApplication, x: CGFloat, y: CGFloat, size: CGFloat = 18) {
    let origin = point(app, x, y)
    let at = { (dx: CGFloat, dy: CGFloat) in origin.withOffset(CGVector(dx: dx, dy: dy)) }
    let third = size / 3
    at(third, 0).press(forDuration: 0.05, thenDragTo: at(third, size))
    at(2 * third, 0).press(forDuration: 0.05, thenDragTo: at(2 * third, size))
    at(0, third).press(forDuration: 0.05, thenDragTo: at(size, third))
    at(0, 2 * third).press(forDuration: 0.05, thenDragTo: at(size, 2 * third))
  }

  /// Stories 1065, 1066 (#1034): a line started with ## is a level-2 header (▾ ## in the margin) inside the # above
  /// it, and folding the # tucks the ## away with its section.
  func testHashHashMakesASubheaderThatFoldsWithTheHashAbove() throws {
    let app = try openBoard()
    sleep(1)
    let gap = 26 / app.frame.width
    // # then a slanted "word" (a straight flat stroke would be an underline).
    hash(app, x: 0.12, y: 0.29)
    wait(send(app), label: strokes(4))
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), "a # makes a header: \(app.debugDescription)")
    point(app, 0.12 + 2 * gap, 0.29).press(forDuration: 0.05, thenDragTo: point(app, 0.30, 0.31))
    write(app, x: 0.16, to: 0.34, y: 0.36)
    // ## then its word, and a line under it.
    hash(app, x: 0.12, y: 0.43)
    hash(app, x: 0.12 + gap, y: 0.43)
    point(app, 0.12 + 3 * gap, 0.43).press(forDuration: 0.05, thenDragTo: point(app, 0.30, 0.45))
    write(app, x: 0.16, to: 0.34, y: 0.50)
    wait(send(app), label: strokes(16))
    let headers = marks(app, "Header")
    XCTAssertTrue(headers.element(boundBy: 1).appears(within: 5), "two headers: \(app.debugDescription)")
    let values = (0..<headers.count).map { headers.element(boundBy: $0).value as? String ?? "" }
    XCTAssertEqual(values.sorted(), ["▾", "▾ ##"], "the second line is a ##")
    shot(app, "a # and a ## under it")
    // Folding the # takes the ## with it: one folded mark, no open one.
    point(app, margin, 0.30).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), "it folds: \(app.debugDescription)")
    XCTAssertTrue(headers.firstMatch.waitForNonExistence(timeout: 5), "the ## folded away inside the #")
    shot(app, "the # folded with its ##")
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

  /// Story 900 (#1013): Send on a folded board gives Larry the folded lines whole and shaded, the picture taller by
  /// them, with where they are beside its frame; the board on the iPad stays folded.
  func testLarrysPictureShowsAFoldedSectionWholeAndShaded() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    sleep(1)
    write(app, x: 0.12, to: 0.4, y: 0.30)
    write(app, x: 0.2, to: 0.5, y: 0.36)
    write(app, x: 0.2, to: 0.5, y: 0.42)
    write(app, x: 0.12, to: 0.4, y: 0.52)
    wait(send(app), label: strokes(4))
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Header").firstMatch.appears(within: 5), app.debugDescription)
    point(app, margin, 0.305).tap()
    XCTAssertTrue(marks(app, "Folded header").firstMatch.appears(within: 5), app.debugDescription)
    sleep(1)
    let before = Set(try boardMessages(cockpit).compactMap { $0["picture_id"] as? String })
    send(app).tap()
    let message = try newBoardMessage(cockpit, besides: before)
    let folds = try XCTUnwrap(message["picture_folds"] as? [[String: Any]], "the folds beside the frame: \(message)")
    XCTAssertEqual(folds.count, 1, "\(folds)")
    let fold = try XCTUnwrap(folds.first)
    let (y, h) = (try XCTUnwrap(fold["y"] as? Double), try XCTUnwrap(fold["h"] as? Double))
    XCTAssertGreaterThan(h, 0, "the picture grows by the folded lines: \(fold)")
    let frame = try XCTUnwrap(message["frame"] as? [String: Any])
    let (top, scale) = (try XCTUnwrap(frame["y"] as? Double), try XCTUnwrap(frame["scale"] as? Double))
    let picture = try XCTUnwrap(UIImage(data: try attachment(cockpit, of: message)), "the picture's bytes")
    let attached = XCTAttachment(image: picture)
    attached.name = "Larry's picture, the folded section whole"
    attached.lifetime = .keepAlways
    add(attached)
    let width = Double(try XCTUnwrap(picture.cgImage).width)
    // At the page's right edge, clear of the ink: white beside the header, the shading across the folded lines.
    let edge = width - 4
    XCTAssertGreaterThan(try grey(picture, x: edge, y: (y - 8 - top) * scale), 0.97, "white above the fold")
    let shaded = try grey(picture, x: edge, y: (y + h / 2 - top) * scale)
    XCTAssertLessThan(shaded, 0.96, "shaded across the folded lines")
    XCTAssertGreaterThan(shaded, 0.85, "a light shade, not ink")
    XCTAssertTrue(marks(app, "Folded header").firstMatch.exists, "the board on the iPad stays folded")
    shot(app, "still folded after Send")
  }

  private func get(_ cockpit: String, _ path: String) throws -> Data {
    let url = try XCTUnwrap(URL(string: cockpit + path))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered \(path)")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    return try XCTUnwrap(got)
  }

  private func json(_ cockpit: String, _ path: String) throws -> [String: Any] {
    try XCTUnwrap(try JSONSerialization.jsonObject(with: try get(cockpit, path)) as? [String: Any])
  }

  /// Igor's board pictures on the fake's threads.
  private func boardMessages(_ cockpit: String) throws -> [[String: Any]] {
    let threads = try XCTUnwrap(try json(cockpit, "/chat")["threads"] as? [[String: Any]])
    return try threads.compactMap { $0["key"] as? String }.flatMap { key in
      (try json(cockpit, "/chat/\(key)")["messages"] as? [[String: Any]] ?? []).filter {
        $0["who"] as? String == "igor" && $0["picture_id"] != nil
      }
    }
  }

  private func newBoardMessage(_ cockpit: String, besides seen: Set<String>) throws -> [String: Any] {
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      if let new = try boardMessages(cockpit).first(where: { !seen.contains($0["picture_id"] as? String ?? "") }) {
        return new
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
    return try XCTUnwrap(nil as [String: Any]?, "no new board picture reached the fake Cockpit")
  }

  private func attachment(_ cockpit: String, of message: [String: Any]) throws -> Data {
    let first = try XCTUnwrap((message["attachments"] as? [Any])?.first, "\(message)")
    let ref = try XCTUnwrap(
      (first as? String) ?? ((first as? [String: Any])?["ref"] as? String), "an attachment's ref: \(first)")
    return try get(cockpit, "/attachments/" + ref)
  }

  /// A pixel's brightness, 0 black to 1 white.
  private func grey(_ image: UIImage, x: Double, y: Double) throws -> Double {
    let cg = try XCTUnwrap(image.cgImage)
    let (px, py) = (Int(x), Int(y))
    XCTAssertTrue((0..<cg.width).contains(px) && (0..<cg.height).contains(py), "(\(px), \(py)) in the picture")
    var pixel: [UInt8] = [0, 0, 0, 0]
    let context = try XCTUnwrap(
      CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(cg, in: CGRect(x: -px, y: py - cg.height + 1, width: cg.width, height: cg.height))
    return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
  }
}
