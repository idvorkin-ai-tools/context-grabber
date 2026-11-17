//  Stories 396, 399 (#613) on the simulator: a swipe deletes a board another device drew, after asking; it stays gone,
//  and a link to it says so. Story 836 (#916): a board drawn here is renamed from its row's swipe and from its name in
//  the bar. The delete and the rename crossing iCloud need two real devices: the simulator has no account.

import XCTest

final class WhiteboardRowDeleteUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// The boards, with a board the iPad drew on a fresh id, so runs on one simulator don't meet each other's boards.
  private func openWithAnIPadBoard(_ id: String) -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = id
    app.launchEnvironment["GRABBER_BOARD_FIXTURE_FROM"] = "iPad"
    app.launch()
    return app
  }

  private func row(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).firstMatch
  }

  private func iPadRows(_ app: XCUIApplication) -> Int {
    app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).count
  }

  func testASwipeAsksThenDeletesABoardDrawnElsewhereAndALinkToItSaysSo() {
    let id = "board-613-\(UUID().uuidString.lowercased())"
    var app = openWithAnIPadBoard(id)
    XCTAssertTrue(row(app).appears(within: 20), app.debugDescription)
    let before = iPadRows(app)

    // A long press offers Delete on a board drawn elsewhere, and no Rename.
    row(app).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Delete"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Rename"].exists, "only its own device renames it")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
    XCTAssertTrue(app.buttons["whiteboard-done"].appears(within: 5), app.debugDescription)

    // The swipe asks first.
    row(app).swipeLeft()
    let delete = app.buttons["Delete"].firstMatch
    XCTAssertTrue(delete.appears(within: 5), app.debugDescription)
    delete.tap()
    let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete Board'")).firstMatch
    XCTAssertTrue(confirm.appears(within: 5), app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    confirm.tap()
    let fewer = NSPredicate { _, _ in self.iPadRows(app) == before - 1 }
    wait(for: [expectation(for: fewer, evaluatedWith: app)], timeout: 10)

    // Still gone next launch, and a link to it is a copyable problem.
    app.terminate()
    app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://whiteboard?board=\(id)"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 20), app.debugDescription)
    XCTAssertEqual(iPadRows(app), before - 1, app.debugDescription)
  }

  /// Types `name` into the rename box, over the name it was filled with, and confirms.
  private func rename(_ app: XCUIApplication, to name: String) {
    let field = app.alerts.textFields.firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.tap()
    let old = field.value as? String ?? ""
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2) + name)
    app.alerts.buttons["Rename"].tap()
  }

  func testABoardDrawnHereIsRenamedFromItsRowAndFromItsBar() {
    let id = "board-916-\(UUID().uuidString.lowercased())"
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = id
    app.launch()
    let cards = app.buttons.matching(identifier: "whiteboard-card")
    XCTAssertTrue(cards.firstMatch.appears(within: 20), app.debugDescription)

    // The swipe offers Rename beside Delete. The fixture, just added, is the newest row.
    let fromRow = "Row \(id.suffix(6))"
    cards.firstMatch.swipeLeft()
    let swipeRename = app.buttons["Rename"].firstMatch
    XCTAssertTrue(swipeRename.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["Delete"].exists, "beside Delete")
    swipeRename.tap()
    rename(app, to: fromRow)
    let row = cards.matching(NSPredicate(format: "label CONTAINS %@", fromRow)).firstMatch
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)

    // The name in the bar opens a menu with Rename, and the bar and the row follow.
    row.tap()
    let title = app.navigationBars.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", fromRow)).firstMatch
    XCTAssertTrue(title.appears(within: 10), app.debugDescription)
    title.tap()
    let barRename = app.buttons["whiteboard-rename"].firstMatch
    XCTAssertTrue(barRename.appears(within: 5), app.debugDescription)
    barRename.tap()
    let fromBar = "Bar \(id.suffix(6))"
    rename(app, to: fromBar)
    let renamed = app.navigationBars.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", fromBar)).firstMatch
    XCTAssertTrue(renamed.appears(within: 5), app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(
      cards.matching(NSPredicate(format: "label CONTAINS %@", fromBar)).firstMatch.appears(within: 10),
      app.debugDescription)
  }
}
