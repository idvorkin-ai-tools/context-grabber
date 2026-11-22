//  Story 1160 (context-grabber-5chm) on the iPad simulator: a tap on the board's name in its own bar renames it, as the
//  row's Rename does; the stroke after it draws, the Board menu still opens and closes (a title menu once kept it up,
//  d33c7d0d), and the list has the new name. Another device's board has a plain name. Crossing iCloud is the iPad's.

import XCTest

final class WhiteboardTitleRenameUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func launch(fixture id: String? = nil, from device: String? = nil) -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    if let id { app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = id }
    if let device { app.launchEnvironment["GRABBER_BOARD_FIXTURE_FROM"] = device }
    app.launch()
    return app
  }

  private func send(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-send"] }

  private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 8) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func stroke(_ app: XCUIApplication) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
    start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45)))
  }

  func testATapOnTheBoardsNameRenamesItAndTheBoardStillDraws() {
    let app = launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    // Ghosts off, so a stroke asks nothing of a Cockpit.
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }

    // The name in the bar opens the rename box, filled with the board's name.
    let title = app.buttons["whiteboard-title"]
    XCTAssertTrue(title.appears(within: 10), app.debugDescription)
    let before = title.label
    XCTAssertTrue(before.hasPrefix("Board, "), "a new board is named for the day: \(before)")
    title.tap()
    let field = app.alerts.textFields.firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    XCTAssertEqual(field.value as? String, before, "filled with the current name")
    // A long name: the bar cuts it short rather than pushing its buttons away.
    let name = "Energy week \(UUID().uuidString.prefix(6)) and everything else this board is about"
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: before.count + 2) + name)
    XCTAssertEqual(field.value as? String, name, "the old name cleared")
    app.alerts.buttons["Rename"].tap()

    // The bar shows it at once, and every button stays on the bar.
    waitFor(title, label: name)
    XCTAssertTrue(send(app).isHittable, app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-board"].isHittable, app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-undo"].exists, app.debugDescription)

    // The stroke after the box draws.
    sleep(1)
    XCTAssertEqual(send(app).label, "Send to Larry, 0 strokes", "closing the box drew nothing")
    stroke(app)
    waitFor(send(app), label: "Send to Larry, 1 strokes")

    // The Board menu opens, takes a colour and closes, and the bar keeps its buttons.
    let board = app.buttons["whiteboard-board"]
    board.tap()
    let grey = app.descendants(matching: .any)["Grey"].firstMatch
    XCTAssertTrue(grey.appears(within: 5), app.debugDescription)
    // #880: the iPad simulator's on-screen keyboard can cancel the first tap on a menu row; try again while it's up.
    for _ in 0..<3 {
      grey.tapWhenSettled()
      let deadline = Date().addingTimeInterval(2)
      while Date() < deadline, grey.exists, board.label != "Board, Grey" {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      }
      guard grey.exists, board.label != "Board, Grey", grey.isHittable else { break }
    }
    waitFor(board, label: "Board, Grey", timeout: 10)
    XCTAssertTrue(send(app).isHittable, "the Board menu closed and the bar's buttons are back: \(app.debugDescription)")
    XCTAssertTrue(title.isHittable, app.debugDescription)
    stroke(app)
    waitFor(send(app), label: "Send to Larry, 2 strokes")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)

    // Back in the list, the row has the new name.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let row = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
  }

  func testAnotherDevicesBoardHasAPlainName() {
    let id = "board-5chm-\(UUID().uuidString.lowercased())"
    let app = launch(fixture: id, from: "iPad")
    let row = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).firstMatch
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    row.tap()
    XCTAssertTrue(send(app).appears(within: 10), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-title"].exists, "a look-only board's name doesn't rename")
  }
}
