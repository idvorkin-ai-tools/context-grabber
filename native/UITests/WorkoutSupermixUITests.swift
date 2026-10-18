//  #220, #372: the Workout Supermix tile opens Igor's mix straight in YouTube Music. The simulator has no YouTube
//  Music, so the link falls back to the browser and this checks that Safari comes to the front; the app is the phone's.

import XCTest

final class WorkoutSupermixUITests: XCTestCase {
  func testTheTileOpensTheMix() throws {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-workout_supermix"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    if !row.isHittable { app.swipeUp() }
    row.tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "the mix opened in the browser")
  }

  // Story 221 (#383): press and hold shows the three mixes, each with its icon, and a choice opens that mix.
  func testTheHoldMenuShowsEachMixWithItsIcon() throws {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-workout_supermix"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    if !row.isHittable { app.swipeUp() }
    row.press(forDuration: 1.5)
    for id in ["workout", "liked", "feel_good"] {
      let choice = app.buttons["supermix-\(id)"]
      XCTAssertTrue(choice.waitForExistence(timeout: 10), "\(id) is in the menu: \(app.debugDescription)")
      XCTAssertGreaterThan(choice.images.count, 0, "\(id) has an icon: \(choice.debugDescription)")
    }
    app.buttons["supermix-liked"].tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "the mix opened in the browser")
  }
}
