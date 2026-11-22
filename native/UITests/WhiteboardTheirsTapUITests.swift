//  Story 1101 (#1171) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): Larry's
//  three circles kept with Keep all, each its own thing; a finger tap on the first selects that circle alone, a finger
//  drags it alone, and one Undo puts it back. Where the circles sit is read from the screen's pixels (`PaperScreen`,
//  in WhiteboardPaperGhostsUITests.swift); what is selected, from To text, which shows beside the selected ink. Which
//  strokes a tap reaches is `BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`.

import XCTest

final class WhiteboardTheirsTapUITests: XCTestCase {
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

  func testAFingerTapOnOneOfLarrysKeptMarksSelectsItAloneAndItDragsAlone() throws {
    let cockpit = try cockpit()
    let app = XCUIApplication.forTests(animated: true)
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
    // Keep all: three circles in a row, each kept as its own thing, not grouped.
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tap()
    waitUntil(NSPredicate(format: "label != %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    let label = send.label
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his three circles in his purple")
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertFalse(toText.exists, "nothing selected yet")
    shot(app, "kept all")

    // The first circle's left side: the circles are 40 board points wide, touching, so the first is the left third.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(toText.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(toText.exists, "still selected a beat later")
    XCTAssertEqual(send.label, label, "no dot drawn for the tap")
    shot(app, "one circle selected by a tap")

    // A finger drags it down by a tenth of the window, from its middle.
    let first = CGPoint(x: kept.minX + kept.width / 6, y: kept.center.y)
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: first.x, dy: first.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: first.x, dy: first.y + 0.1))
    from.press(forDuration: 0.3, thenDragTo: to)
    let moved = PaperScreen.showing(app, { $0.larryKept }, { abs($0.maxY - kept.maxY - 0.1) < 0.03 })
    shot(app, "dragged")
    let after = try XCTUnwrap(moved, "his circles, after the drag")
    XCTAssertEqual(after.minY, kept.minY, accuracy: 0.01, "the other two stayed: \(kept) to \(after)")
    XCTAssertEqual(after.maxY, kept.maxY + 0.1, accuracy: 0.03, "one moved down: \(kept) to \(after)")
    XCTAssertEqual(send.label, label, "moved, not drawn")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let back = PaperScreen.showing(app, { $0.larryKept }, { abs($0.maxY - kept.maxY) < 0.01 })
    shot(app, "after one undo")
    XCTAssertEqual(try XCTUnwrap(back).maxY, kept.maxY, accuracy: 0.01, "one Undo put it back")
  }
}
