//  Story 1222 (beads context-grabber-wvpv, context-grabber-yfsz): Settings → PaperKit board shows its tool picker and
//  the picker's + at once, the + offers the shapes, and a finger stroke lands on the page. On build 5569178f none of
//  that showed on the iPad ("Nothing there?"), and nothing caught it: this is the check that would have.
//  Run it on an iPad simulator; on a phone it skips (the row is not there).
//  Run: xcodebuild … -only-testing:GrabberNativeUITests/IPadPaperKitBoardUITests

import XCTest

final class IPadPaperKitBoardUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testThePickersPlusOffersTheShapesAndAFingerDraws() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad simulator only")
    let app = XCUIApplication.forTests()
    app.launch()
    app.openHomeSettings()
    let row = app.buttons["home-paperkit-board"]
    for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 5), "the PaperKit board row: \(app.debugDescription)")
    row.tap()

    // The picker and its + show with nothing tapped on the page first, the page full screen, not in Settings' sheet.
    let insert = app.buttons["paperkit-board-insert"]
    XCTAssertTrue(insert.appears(within: 5), "the tool picker's +: \(app.debugDescription)")

    // A finger stroke lands on the page.
    let page = app.otherElements["paperkit-board"]
    XCTAssertTrue(page.appears(within: 5), app.debugDescription)
    let start = page.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
    start.press(forDuration: 0.05, thenDragTo: page.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45)))
    let drew = NSPredicate(format: "value != '0 elements'")
    let landed = XCTNSPredicateExpectation(predicate: drew, object: page)
    XCTAssertEqual(XCTWaiter().wait(for: [landed], timeout: 5), .completed, "page: \(page.value ?? "nil")")

    // The + offers the shapes and a text box (PaperKit's own insert menu).
    insert.tap()
    XCTAssertTrue(app.staticTexts["Add Shape"].appears(within: 5), "the insert menu: \(app.debugDescription)")
    XCTAssertTrue(app.staticTexts["Add Text"].exists, "the insert menu: \(app.debugDescription)")
  }
}
