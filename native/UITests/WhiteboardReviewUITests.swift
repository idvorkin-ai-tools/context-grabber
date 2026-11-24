//  Stories 1237, 1240, 1242–1246 on the iPad simulator (spec 2026-11-23-board-interaction-review-design.md, bead
//  context-grabber-8ao5.2): a session reviewed after idle (`GRABBER_WHITEBOARD_REVIEW_IDLE` shortens five minutes to
//  seconds) shows its quiet note only for a finding, here one `GRABBER_WHITEBOARD_REVIEW_FINDING` stands in (a Keep that
//  changed the pen, which the simulator can't make); the note opens the findings, each copyable with *Show me*; a review
//  asked for from the Board menu says when it is clean. The checks themselves are `BoardReviewTests` and the recorder
//  `BoardReviewRecorderTests`, on the host; a real session reviewed after idle is the iPad's.

import XCTest

final class WhiteboardReviewUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func launch(_ env: [String: String]) -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    for (key, value) in env { app.launchEnvironment[key] = value }
    app.launch()
    return app
  }

  /// A new board with the pen picked and one stroke on it.
  private func strokeOnANewBoard(_ app: XCUIApplication) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let send = app.buttons["whiteboard-send"]
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    sleep(2)
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected {
      pen.tap()
      sleep(1)
    }
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)))
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
  }

  private func keep(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  func testAFindingAfterIdleShowsTheNoteAndOpensCopyableWithShowMe() {
    let app = launch(["GRABBER_WHITEBOARD_REVIEW_IDLE": "3", "GRABBER_WHITEBOARD_REVIEW_FINDING": "1"])
    strokeOnANewBoard(app)
    let note = app.buttons["whiteboard-review-note"]
    XCTAssertTrue(note.appears(within: 20), "story 1243: the note after idle: \(app.debugDescription)")
    XCTAssertEqual(note.label, "Reviewed · 1 to look at")
    keep(app, "the review's note")
    note.tap()
    let finding = app.descendants(matching: .any)["whiteboard-review-finding"].firstMatch
    XCTAssertTrue(finding.appears(within: 5), app.debugDescription)
    XCTAssertTrue(finding.label.contains("pen changed"), finding.label)
    let copy = app.buttons["whiteboard-review-copy"].firstMatch
    copy.tap()
    waitUntil(NSPredicate(format: "label == 'Copied'"), copy, timeout: 5)
    app.buttons["whiteboard-review-show"].firstMatch.tap()
    let step = app.descendants(matching: .any)["whiteboard-review-step"]
    XCTAssertTrue(step.appears(within: 5), "story 1245: Show me: \(app.debugDescription)")
    XCTAssertEqual(step.label, "the board before the step")
    app.segmentedControls["whiteboard-review-before-after"].buttons["After"].tap()
    waitUntil(NSPredicate(format: "label == 'the board after the step'"), step, timeout: 5)
    keep(app, "Show me, after")
    app.buttons["Done"].firstMatch.tap()
    app.buttons["whiteboard-review-done"].tap()
    XCTAssertTrue(app.buttons["whiteboard-send"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(note.exists, "story 1243: opened, the note goes")
  }

  func testAReviewAskedForFromTheBoardMenuSaysClean() {
    let app = launch(["GRABBER_WHITEBOARD_REVIEW_IDLE": "600"])
    strokeOnANewBoard(app)
    XCTAssertFalse(app.buttons["whiteboard-review-note"].exists, "nothing before a review")
    app.buttons["whiteboard-board"].tap()
    let review = app.descendants(matching: .any)["whiteboard-review-session"].firstMatch
    XCTAssertTrue(review.appears(within: 5), app.debugDescription)
    // #880: the simulator's keyboard rising under a menu can cancel a tap; tap again while the menu is still up.
    let note = app.buttons["whiteboard-review-note"]
    for _ in 0..<3 {
      review.tapWhenSettled()
      if note.appears(within: 3) || !review.exists { break }
    }
    XCTAssertTrue(note.appears(within: 10), "story 1240: \(app.debugDescription)")
    XCTAssertEqual(note.label, "Reviewed · clean", "story 1242: clean, because he asked")
    keep(app, "a clean review he asked for")
  }
}
