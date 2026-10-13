//  The home screen's Settings tile (#286): the last tile, so it can be below the fold, and the home list is lazy: a
//  tile scrolled off the screen is not in the hierarchy at all. Scroll to it, then tap.

import XCTest

extension XCUIApplication {
  func openHomeSettings(timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      buttons["home-call"].waitForExistence(timeout: timeout) || buttons["home-settings"].exists,
      "the home screen: \(debugDescription)", file: file, line: line)
    let tile = buttons["home-settings"]
    for _ in 0..<8 where !(tile.exists && tile.isHittable) { swipeUp() }
    XCTAssertTrue(tile.waitForExistence(timeout: 5), "the Settings tile: \(debugDescription)", file: file, line: line)
    tile.tap()
  }
}
