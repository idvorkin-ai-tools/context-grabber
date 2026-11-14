//  Story 242 (#156): Today asks to write Mindful Minutes; then a finished breathing session lands in Health and
//  the mirror's Meditation card counts it. Cue off: no sound needed (this Mac's audio is broken anyway). What this alone
//  proves is the write to Health, so the ladder runs it for the Health source, not for a breathing change: when a
//  session is saved is `BreathSessionTests`, on the host (story 770).

import XCTest

final class BreatheMindfulUITests: XCTestCase {
  func testAFinishedSessionIsSavedToHealth() throws {
    // Today asks to read Health and to write Mindful Minutes, in one sheet; allow it.
    let first = XCUIApplication.forTests()
    first.launch()
    let today = first.buttons["home-today-card"]
    XCTAssertTrue(today.appears(within: 15), first.debugDescription)
    today.tap()
    // Measured 37 s on this Mac (2026-10-08) for Health's sheet to come up; give it 90. No sheet means access was
    // granted on this simulator before, and then the grab goes past asking and Today's cards show: that ends the wait
    // (it sat out all 90 s before story 770). Twice, a second apart, so a card drawn before the grab starts asking
    // doesn't count. The Meditation count below is what decides.
    let sheet = first.navigationBars["Health Access"]
    let meditationCard = first.buttons["card-meditation"]
    let asking = first.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Health access'")).firstMatch
    let deadline = Date().addingTimeInterval(90)
    var settled = 0
    while Date() < deadline, !sheet.exists, settled < 2 {
      settled = meditationCard.exists && !asking.exists ? settled + 1 : 0
      if settled < 2 { RunLoop.current.run(until: Date().addingTimeInterval(1)) }
    }
    if sheet.exists {
      XCTAssertTrue(HealthSheet.allow(in: first) { !sheet.exists }, "Health's sheet stayed: \(first.debugDescription)")
    }
    first.terminate()

    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_BREATHE"] = "5,3,off"  // three 20 s cycles: one minute, no sound
    app.launch()
    XCTAssertTrue(app.staticTexts["Done"].appears(within: 90), app.debugDescription)
    if app.buttons["Back to start"].exists { app.buttons["Back to start"].tap() }
    let close = app.buttons["breathe-close"]
    XCTAssertTrue(close.appears(within: 10), app.debugDescription)
    close.tap()
    let card = app.buttons["home-today-card"]
    XCTAssertTrue(card.appears(within: 15), app.debugDescription)
    card.tap()
    let meditation = app.buttons["card-meditation"]
    XCTAssertTrue(meditation.appears(within: 15), app.debugDescription)
    let counted = expectation(for: NSPredicate(format: "label CONTAINS '1 min'"), evaluatedWith: meditation)
    XCTAssertEqual(
      XCTWaiter().wait(for: [counted], timeout: 30), .completed, "Meditation counts it: \(meditation.label)")
  }
}
