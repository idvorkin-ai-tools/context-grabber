//  #284–#286: every launcher is the same small tile, three to a line, its icon above a short name; Recent and Random
//  share a line; Settings is the last tile and opens the Home screen sheet (the floating cog is gone).

import XCTest

final class HomeGridUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testTilesGoThreeToALineWithSettingsLast() throws {
    let app = XCUIApplication()
    app.launch()
    // Igor's default order, whatever an earlier run left.
    app.openHomeSettings()
    let reset = app.buttons["home-rows-reset"]
    for _ in 0..<6 where !reset.isHittable { app.swipeUp() }
    reset.tap()
    app.buttons["home-settings-done"].tap()

    let call = app.buttons["home-call"], timer = app.buttons["home-gym_timer"], breathe = app.buttons["home-breathe"]
    for _ in 0..<6 where !call.isHittable { app.swipeDown() }
    XCTAssertTrue(call.waitForExistence(timeout: 10), app.debugDescription)
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

    // Recent and Random side by side (#285), and Settings alone on the last line, a tile like the rest (#286).
    let recent = app.buttons["home-recent"], random = app.buttons["home-random"], settings = app.buttons["home-settings"]
    for _ in 0..<8 where !(settings.exists && settings.isHittable) { app.swipeUp() }
    XCTAssertTrue(recent.exists && random.exists && settings.exists, app.debugDescription)
    XCTAssertEqual(recent.frame.midY, random.frame.midY, accuracy: 4, "Recent and Random share a line")
    XCTAssertGreaterThan(settings.frame.minY, random.frame.maxY, "Settings comes after the launchers")
    XCTAssertEqual(settings.frame.width, recent.frame.width, accuracy: 2, "Settings is a tile like the rest")
    XCTAssertEqual(settings.frame.minX, call.frame.minX, accuracy: 2, "Settings starts its line")

    settings.tap()
    XCTAssertTrue(app.navigationBars["Home screen"].waitForExistence(timeout: 5), app.debugDescription)
  }
}
