//  Story 947 (#947) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a finger
//  tap on one stroke of a kept group selects the whole group, a finger drags it as one, and one Undo puts it back. Where
//  the group sits is read from the screen's pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift); what is
//  selected, from To text, which shows beside the selected ink. Which strokes a tap reaches is `BoardOutlineTests`.

import XCTest

final class WhiteboardGroupTapUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func larryDraws(_ count: Int, _ cockpit: String) throws {
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

  private func toKeep(_ app: XCUIApplication, _ count: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label == %@", "\(count) to keep")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Larry's three circles kept as one group on a new board, Ghosts off, nothing left showing; the Send button's label
  /// once they are ink.
  private func keptGroup(_ app: XCUIApplication) throws -> String {
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
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    group.tap()
    waitUntil(NSPredicate(format: "label != %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    XCTAssertTrue(toKeep(app, 1).waitForNonExistence(timeout: 5) || !toKeep(app, 1).exists)
    return send.label
  }

  func testAFingerTapOnAGroupsStrokeSelectsItAllAndItDragsAsOne() throws {
    let app = XCUIApplication.forTests(animated: true)
    let label = try keptGroup(app)
    let send = app.buttons["whiteboard-send"]
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his reply in his purple")
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertFalse(toText.exists, "nothing selected yet")
    shot(app, "kept group")

    // The first circle's left side: one stroke of the three.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(toText.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(toText.exists, "still selected a beat later")
    let window = app.windows.firstMatch.frame
    let selected = toText.frame
    shot(app, "the group selected by a tap")
    XCTAssertEqual(send.label, label, "no dot drawn for the tap")
    // To text sits beside the selection, so it spans the whole group, not one circle.
    XCTAssertGreaterThan(selected.maxX / window.width, kept.maxX - 0.05, "the whole group selected: \(selected)")

    // A finger drags it down by a tenth of the window, from inside the selection (its edges are PaperKit's handles).
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + 0.1))
    from.press(forDuration: 0.3, thenDragTo: to)
    let moved = PaperScreen.showing(app, { $0.larryKept }, { abs($0.minY - kept.minY - 0.1) < 0.03 })
    shot(app, "dragged")
    let after = try XCTUnwrap(moved, "his group, after the drag")
    XCTAssertEqual(after.minY, kept.minY + 0.1, accuracy: 0.03, "moved down: \(kept) to \(after)")
    XCTAssertEqual(after.width, kept.width, accuracy: 0.01, "all of it moved, together")
    XCTAssertEqual(send.label, label, "moved, not drawn")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let back = PaperScreen.showing(app, { $0.larryKept }, { abs($0.minY - kept.minY) < 0.01 })
    shot(app, "after one undo")
    XCTAssertEqual(try XCTUnwrap(back).minY, kept.minY, accuracy: 0.01, "one Undo put it back")
    XCTAssertEqual(back?.width ?? 0, kept.width, accuracy: 0.01)
  }

  /// Off every group the tap does what it did: nothing is selected.
  func testATapBesideTheGroupSelectsNothing() throws {
    let app = XCUIApplication.forTests(animated: true)
    _ = try keptGroup(app)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his reply in his purple")
    PaperScreen.tap(app, CGPoint(x: kept.center.x, y: kept.maxY + 0.08))
    sleep(2)
    XCTAssertFalse(app.buttons["whiteboard-to-text"].exists, "blank paper beside it selects nothing")
  }
}
