//  Stories 435–439, 524–534 on the simulator: *Try on paper* opens a copy, nothing in it reaches the real board, and another
//  device's board doesn't offer it. How it feels and what a finger does with a Pencil paired are the iPad's: `just
//  pull-logs` and read `paper_probe`. A finger draws on the simulator.

import XCTest

final class WhiteboardTrialOnPaperUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// Ghosts ask nowhere real: an address nothing answers.
  private func launch(_ environment: [String: String] = [:]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_WHITEBOARD_NEW_ON_PAPER"] = "off"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    for (key, value) in environment { app.launchEnvironment[key] = value }
    app.launch()
    return app
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 8) {
    expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
    waitForExpectations(timeout: timeout)
  }

  private func keep(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  func testDrawingInTheTrialLeavesTheRealBoardAlone() {
    let app = launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let send = app.buttons["whiteboard-send"]
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    sleep(1)
    stroke(app, atHeight: 0.5)
    waitFor(send, label: "Send to Larry, 1 strokes")
    app.navigationBars.buttons.element(boundBy: 0).tap()

    let row = app.buttons["whiteboard-card"].firstMatch
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    // The row's "Changed …" part is relative to now, so it moves with the clock; the name and stroke count do not.
    let before = row.label.components(separatedBy: ", Changed").first
    row.press(forDuration: 1.2)
    let tryIt = app.buttons["Try on paper"]
    XCTAssertTrue(tryIt.appears(within: 5), app.debugDescription)
    tryIt.tap()

    // Story 437: the line, the page number and the menu with the copy's one stroke.
    let menu = app.buttons["paper-trial-menu"]
    XCTAssertTrue(menu.appears(within: 15), app.debugDescription)
    XCTAssertTrue(app.staticTexts["paper-trial-note"].exists, app.debugDescription)
    waitFor(menu, label: "Trial, 1 strokes")
    XCTAssertTrue(
      app.staticTexts["paper-trial-page"].label.hasPrefix("Page 1 of "), app.staticTexts["paper-trial-page"].label)
    keep(app, "trial opened")

    // Story 527: nothing in here but the trial's own: no Send, no Larry's turn, no ghosts, no mic.
    for id in ["whiteboard-send", "whiteboard-larry", "whiteboard-ghosts", "whiteboard-mic"] {
      XCTAssertFalse(app.buttons[id].exists, id)
    }

    // A finger draws here on the simulator, so the copy gains ink; the menu's own count says so.
    sleep(2)
    stroke(app, atHeight: 0.6)
    waitFor(menu, label: "Trial, 2 strokes", timeout: 10)
    stroke(app, atHeight: 0.7)
    waitFor(menu, label: "Trial, 3 strokes", timeout: 10)
    keep(app, "trial drawn on")

    // Stories 530, 531: the menu's switches run; the log's `paper_probe` lines are what they're for.
    menu.tap()
    let add = app.buttons["Add a page now"]
    XCTAssertTrue(add.appears(within: 5), app.debugDescription)
    add.tap()
    sleep(2)
    keep(app, "trial with a page added")
    menu.tap()
    let far = app.buttons["Go to page 11"]
    XCTAssertTrue(far.appears(within: 5), app.debugDescription)
    far.tap()
    expectation(
      for: NSPredicate(format: "label BEGINSWITH 'Page 11 of'"), evaluatedWith: app.staticTexts["paper-trial-page"])
    waitForExpectations(timeout: 8)
    keep(app, "trial on page 11")
    menu.tap()
    let inPlace = app.buttons["Ink where it is"]
    XCTAssertTrue(inPlace.appears(within: 5), app.debugDescription)
    inPlace.tap()
    waitFor(menu, label: "Trial, 1 strokes", timeout: 10)
    sleep(1)
    // Question 4: where a new stroke lands when the column's corner is far from zero (`stroke_landing`).
    stroke(app, atHeight: 0.6)
    waitFor(menu, label: "Trial, 2 strokes", timeout: 10)
    keep(app, "trial with the ink where it is")

    app.buttons["paper-trial-close"].tap()

    // The real board: its row reads as it did, and it holds the one stroke it had. Not a mark from the trial.
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    XCTAssertEqual(row.label.components(separatedBy: ", Changed").first, before)
    row.tap()
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    waitFor(send, label: "Send to Larry, 1 strokes")
  }

  /// Drives every switch with a finger, so a run's `paper_probe` lines hold what the simulator can say about the
  /// questions. What a finger does is PaperKit's to decide and the log's to record, so only the trial surviving it all
  /// is asserted, with the Pencil's half left to the iPad.
  func testEverySwitchRunsForTheLog() {
    let id = "paper-probes-\(UUID().uuidString.lowercased())"
    let app = launch([
      "GRABBER_BOARD_FIXTURE": id, "GRABBER_PAPER_TRIAL": id, "GRABBER_PAPER_TRIAL_INK": "40",
    ])
    let menu = app.buttons["paper-trial-menu"]
    XCTAssertTrue(menu.appears(within: 20), app.debugDescription)
    waitFor(menu, label: "Trial, 40 strokes", timeout: 10)
    sleep(2)
    keep(app, "probes opened")

    func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
      app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    func drag(_ from: XCUICoordinate, _ to: XCUICoordinate) {
      from.press(forDuration: 0.05, thenDragTo: to)
      sleep(1)
    }
    func choose(_ item: String) {
      menu.tap()
      let entry = app.descendants(matching: .any)[item].firstMatch
      XCTAssertTrue(entry.appears(within: 5), item + app.debugDescription)
      entry.tap()
      sleep(1)
    }
    // The first row of ink, and blank paper well below it, on an iPad's width.
    let ink = point(200, 160)
    let blank = point(300, 700)
    for finger in ["Selects", "Lock the ink", "Draws", "The system's choice"] {
      choose(finger)
      ink.tap()
      sleep(1)
      drag(ink, point(400, 500))
      drag(blank, point(300, 400))
      blank.tap()
      sleep(1)
      keep(app, "after \(finger)")
    }
    app.pinch(withScale: 0.5, velocity: -1)
    sleep(1)
    app.pinch(withScale: 2, velocity: 1)
    sleep(1)

    // A page landing in the middle of a stroke (question 2): the drag and the hold run past the three seconds.
    choose("Add a page in 3 s")
    point(150, 800).press(
      forDuration: 0.05, thenDragTo: point(600, 900), withVelocity: .slow, thenHoldForDuration: 5)
    sleep(2)
    keep(app, "after a page mid-stroke")
    choose("Count the undos")

    // The fallback: a tall column cut short, and how far the view can then go.
    choose("Tall column, cut short")
    choose("Go to the end")
    sleep(1)
    keep(app, "tall, at the end")
    choose("Add a page now")
    choose("Go to the end")
    sleep(1)
    choose("Count the undos")

    XCTAssertTrue(menu.exists, app.debugDescription)
  }

  func testABoardFromAnotherDeviceDoesNotOfferIt() {
    let app = launch([
      "GRABBER_BOARD_FIXTURE": "paper-trial-\(UUID().uuidString.lowercased())",
      "GRABBER_BOARD_FIXTURE_FROM": "iPad",
    ])
    let row = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).firstMatch
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    row.press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Delete"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Try on paper"].exists, "only this device's boards")
  }
}
