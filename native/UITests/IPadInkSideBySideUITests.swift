//  Story 1209 on the simulator: Settings → Ink side by side opens both halves, the left half draws and its corner
//  counts the stroke. The web half's page needs the real Cockpit, so only its corner is checked here; the numbers
//  themselves are InkLatencyTests' on the host, and the feel is the iPad's.
//  Run it on an iPad simulator; on a phone it skips (the row is not there).
//  Run: xcodebuild … -only-testing:GrabberNativeUITests/IPadInkSideBySideUITests

import XCTest

final class IPadInkSideBySideUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testBothHalvesOpenAndAStrokeOnTheLeftIsCounted() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad simulator only")
    let app = XCUIApplication.forTests()
    app.launch()
    app.openHomeSettings()
    let row = app.buttons["home-ink-side-by-side"]
    for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 5), "the Ink side by side row: \(app.debugDescription)")
    row.tap()

    let native = app.staticTexts["ink-native-readout"]
    let web = app.staticTexts["ink-web-readout"]
    XCTAssertTrue(native.appears(within: 5), app.debugDescription)
    XCTAssertEqual(native.label, "Draw to measure")
    XCTAssertEqual(web.label, "Draw to measure")

    let canvas =
      app.otherElements["ink-native-canvas"].exists
      ? app.otherElements["ink-native-canvas"] : app.scrollViews["ink-native-canvas"]
    XCTAssertTrue(canvas.appears(within: 5), app.debugDescription)
    let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
    start.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))

    let counted = NSPredicate(format: "label BEGINSWITH 'last ' AND label ENDSWITH '1 stroke'")
    let wait = XCTNSPredicateExpectation(predicate: counted, object: native)
    XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "readout: \(native.label)")
  }
}
