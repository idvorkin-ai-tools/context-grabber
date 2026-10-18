//  #391, stories 222-225: press and hold a home tile for a popover of its choices; a choice opens as its own tile
//  would. The light tick and the drawn art are the phone's to judge.

import XCTest

final class HoldPopoverUITests: XCTestCase {
  private func hold(_ tile: String, in app: XCUIApplication) {
    let row = app.buttons["home-\(tile)"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    for _ in 0..<4 where !row.isHittable { app.swipeUp() }
    row.press(forDuration: 1.5)
  }

  // Story 223: the timer's presets and Custom, and a preset starts its workout.
  func testTheTimerPopoverStartsAPreset() throws {
    let app = XCUIApplication()
    app.launch()
    hold("gym_timer", in: app)
    for id in ["30sec", "1min", "2min", "5-1", "custom"] {
      XCTAssertTrue(app.buttons["timer-\(id)"].waitForExistence(timeout: 10), "\(id): \(app.debugDescription)")
    }
    app.buttons["timer-1min"].tap()
    let face = app.descendants(matching: .any).matching(identifier: "timer-face").firstMatch
    XCTAssertTrue(face.waitForExistence(timeout: 10), "the timer opened: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["STOP"].waitForExistence(timeout: 10), "and started")
  }

  // Story 225: Drill the stack from the card's popover opens the drill without the card screen's button.
  func testTheCardPopoverOpensTheDrill() throws {
    let app = XCUIApplication()
    app.launch()
    hold("think_a_card", in: app)
    XCTAssertTrue(app.buttons["card-think"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(app.buttons["card-face"].exists)
    app.buttons["card-drill"].tap()
    XCTAssertTrue(app.staticTexts["Tap to see its position"].waitForExistence(timeout: 10), app.debugDescription)
  }

  // Story 222: a tap outside closes the popover with nothing opened, and the tile's tap still works after a hold.
  func testATapOutsideOpensNothing() throws {
    let app = XCUIApplication()
    app.launch()
    hold("breathe", in: app)
    XCTAssertTrue(app.buttons["breathe-10"].waitForExistence(timeout: 10), app.debugDescription)
    // UIKit's region outside a popover; a tap at the very top lands in the status bar and never reaches it.
    let outside = app.otherElements["PopoverDismissRegion"]
    XCTAssertTrue(outside.waitForExistence(timeout: 5), app.debugDescription)
    outside.tap()
    XCTAssertFalse(app.buttons["breathe-10"].waitForExistence(timeout: 2), "the popover closed")
    XCTAssertTrue(app.buttons["home-breathe"].isHittable, "still on the home screen")
  }
}
