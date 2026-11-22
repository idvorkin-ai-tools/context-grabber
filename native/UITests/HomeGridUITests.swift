//  #284–#286: every launcher is the same small tile, three to a line, its drawn art (#304, no name); Recent and Random
//  share a line; Settings is the last tile and opens the Home screen sheet (the floating cog is gone). Story 252 (#340,
//  #353): Report a problem is a tile, named for VoiceOver, and a tap opens the same report sheet a shake opens; it was a
//  class of its own and shares this launch now (story 757, #905).

import XCTest

final class HomeGridUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testTilesGoThreeToALineWithSettingsLast() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    // Igor's default order, whatever an earlier run left.
    app.openLaunchers()
    let reset = app.buttons["home-rows-reset"]
    for _ in 0..<6 where !reset.isHittable { app.swipeUp() }
    reset.tap()
    app.buttons["home-settings-done"].tap()

    let call = app.buttons["home-call"]
    let timer = app.buttons["home-gym_timer"]
    let breathe = app.buttons["home-breathe"]
    for _ in 0..<6 where !call.isHittable { app.swipeDown() }
    XCTAssertTrue(call.appears(within: 10), app.debugDescription)
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/home-grid.png"))
    }
    // The first line: three tiles, the same size, side by side.
    for tile in [timer, breathe] {
      XCTAssertEqual(tile.frame.midY, call.frame.midY, accuracy: 4, "\(tile.identifier) is on Call's line")
      XCTAssertEqual(tile.frame.width, call.frame.width, accuracy: 2, "\(tile.identifier) is Call's size")
    }
    XCTAssertLessThan(call.frame.maxX, timer.frame.minX)
    XCTAssertLessThan(timer.frame.maxX, breathe.frame.minX)
    // The fourth starts the next line.
    let places = app.buttons["home-places"]
    XCTAssertGreaterThan(places.frame.minY, call.frame.maxY, "Places starts the second line")
    XCTAssertEqual(places.frame.minX, call.frame.minX, accuracy: 2)

    // Recent and Random side by side (#285); Settings the last tile, a tile like the rest (#286), after Report a
    // problem (story 252).
    let recent = app.buttons["home-recent"]
    let random = app.buttons["home-random"]
    let report = app.buttons["home-report_problem"]
    let settings = app.buttons["home-settings"]
    for _ in 0..<8 where !(settings.exists && settings.isHittable) { app.swipeUp() }
    XCTAssertTrue(recent.exists && random.exists && settings.exists, app.debugDescription)
    XCTAssertEqual(recent.frame.midY, random.frame.midY, accuracy: 4, "Recent and Random share a line")
    XCTAssertGreaterThan(settings.frame.minY, random.frame.maxY, "Settings comes after the launchers")
    XCTAssertEqual(settings.frame.width, recent.frame.width, accuracy: 2, "Settings is a tile like the rest")
    XCTAssertGreaterThan(settings.frame.midY, report.frame.midY - 4, "Settings comes after Report a problem")
    // Settings is the last tile (#693: Inbox and Whiteboard now follow Report a problem, so which line Settings lands
    // on moves with the launchers; that every other tile comes before it does not).
    let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-'")).allElementsBoundByIndex
      .filter { $0.identifier != "home-settings" && abs($0.frame.width - settings.frame.width) < 2 }
    XCTAssertGreaterThan(tiles.count, 10, app.debugDescription)
    for tile in tiles {
      let before =
        tile.frame.midY < settings.frame.midY - 4
        || (abs(tile.frame.midY - settings.frame.midY) < 4 && tile.frame.maxX < settings.frame.minX)
      XCTAssertTrue(before, "\(tile.identifier) comes before Settings")
    }

    // Story 252: the beetle tile opens the report sheet, and Cancel comes back to the tiles.
    XCTAssertEqual(report.label, "Report a problem", "VoiceOver names the tile")
    report.tap()
    XCTAssertTrue(app.navigationBars["Report a problem"].appears(within: 10), app.debugDescription)
    app.buttons["Cancel"].tap()
    XCTAssertTrue(settings.appears(within: 5), app.debugDescription)

    settings.tap()
    XCTAssertTrue(app.navigationBars["Home screen"].appears(within: 5), app.debugDescription)
  }
}
