//  Story 929 (bead context-grabber-9uj2) on the iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): a kept group of Larry's dragged onto Igor's writing pushes the writing down, and one Undo puts both back.
//  Where things sit is read from the screen's pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift): Igor's line
//  in black, Larry's kept marks in his purple. On the simulator a tap selects the group, so this is the selected path;
//  the iPad's drag from PaperKit's handwriting view with nothing selected is `PaperProbePickupTests` on the host.

import XCTest

final class WhiteboardDropRoomUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func post(_ path: String, _ body: String, _ cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func toKeep(_ app: XCUIApplication, _ count: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label == %@", "\(count) to keep")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// A line of Igor's across the middle, and Larry's three circles kept as one group, Ghosts off.
  private func lineAndKeptGroup(_ app: XCUIApplication) throws {
    let cockpit = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "600"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected { pen.tap() }
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    try WhiteboardWordsOnlyFixture.prepare(cockpit, for: self)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(WhiteboardWordsOnlyFixture.reply(in: app).appears(within: 15), app.debugDescription)
    try post("/fake/larry-draws", #"{"count": 3}"#, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    group.tap()
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 4 strokes"), send, timeout: 10)
  }

  func testAGroupDroppedOnMyLinePushesItDownAndOneUndoPutsBothBack() throws {
    let app = XCUIApplication.forTests(animated: true)
    try lineAndKeptGroup(app)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his circles kept")
    let mine = try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "my line")
    XCTAssertGreaterThan(abs(kept.center.y - mine.center.y), 0.08, "the group starts off my line: \(kept) \(mine)")
    shot(app, "my line and the kept group")

    // A tap on one circle selects the group (story 947); a finger drags it onto my line.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(app.buttons["whiteboard-to-text"].appears(within: 5), "the tap selected it: \(app.debugDescription)")
    sleep(2)
    let dy = mine.center.y - kept.center.y
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + dy))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)

    let dropped = PaperScreen.showing(app, within: 10, { $0.larryKept }) { abs($0.center.y - mine.center.y) < 0.03 }
    let pushed = PaperScreen.showing(app, within: 10, { $0.ink }) { box in
      dropped.map { box.minY > $0.maxY } ?? false
    }
    shot(app, "dropped on my line")
    XCTAssertNotNil(dropped, "the group stays where I let go")
    let group = try XCTUnwrap(dropped)
    let line = try XCTUnwrap(pushed, "my line is still on screen")
    XCTAssertGreaterThan(line.minY, group.maxY, "my line moved down clear of the group: \(line) under \(group)")
    XCTAssertEqual(line.minX, mine.minX, accuracy: 0.01, "straight down")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 4 strokes", "moved, not drawn")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let lineBack = PaperScreen.showing(app, within: 10, { $0.ink }) { abs($0.minY - mine.minY) < 0.01 }
    let groupBack = PaperScreen.showing(app, within: 10, { $0.larryKept }) { abs($0.minY - kept.minY) < 0.01 }
    shot(app, "after one undo")
    XCTAssertEqual(lineBack?.minY ?? -1, mine.minY, accuracy: 0.01, "one Undo put my line back")
    XCTAssertEqual(groupBack?.minY ?? -1, kept.minY, accuracy: 0.01, "and the group back where it was")
  }
}
