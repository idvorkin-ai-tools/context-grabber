//  Story 135 (#167): a link opens the app cold where it says, and the Links screen copies them. The link goes
//  through iOS (`XCUIApplication.open`), as a Shortcut's *Open URL* would; where a warm link lands is HomeStackTests'.
//  Bead context-grabber-mzdf: warm links over each kind of screen, now that a link waits for what it closed to say it
//  has gone rather than a fixed pause; the session log's `links` settled says how long each waited.

import XCTest

final class LinksUITests: XCTestCase {
  private func shot(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  /// The warm links (over a running screen, an unknown one, an unknown preset) are host tests now: HomeStackTests'
  /// `testWarmLinksOverTheTimer` and the link pairs (test-ladder card 2). This keeps the one only iOS can do.
  func testATimerLinkStartsTheAppCold() throws {
    let app = XCUIApplication.forTests()
    // Cold: the link launches the app.
    app.open(URL(string: "grabbernative://timer?preset=10,10,2")!)
    XCTAssertTrue(app.buttons["STOP"].appears(within: 20), "the link starts the workout")
    shot(app, "timer-from-link")
  }

  /// A screen comes up over each kind that goes: a cover (the timer, breathing, the card) and a pushed one (Today).
  /// A screen dropped because the one before had not finished going would never show here.
  func testWarmLinksOverEachKindOfScreenBringTheirScreenUp() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let steps: [(link: String, shows: XCUIElement)] = [
      ("timer?preset=10,10,2", app.buttons["STOP"]),
      ("breathe?breath=5&minutes=2", app.buttons["breathe-pause"]),
      ("card", app.buttons["card-done"]),
      ("today", app.navigationBars["Today"]),
      ("timer?preset=10,10,2", app.buttons["STOP"]),
    ]
    // Warm: through the system, as a Shortcut does, so the running app gets it (`app.open` would relaunch it), with
    // iOS's *Open in* question answered.
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for (link, shows) in steps {
      XCUIDevice.shared.system.open(URL(string: "grabbernative://" + link)!)
      let open = springboard.buttons["Open"]
      if open.waitForExistence(timeout: 3) { open.tap() }
      XCTAssertTrue(shows.appears(within: 10), "\(link): \(app.debugDescription)")
    }
    XCTAssertEqual(app.state, .runningForeground, "one launch throughout")
    shot(app, "timer-after-warm-links")
  }

  func testTheLinksScreenCopiesALink() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    // The Links screen sits behind the home screen's Settings tile (story 147).
    app.openHomeSettings()
    let row = app.buttons["home-links"]
    for _ in 0..<5 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    row.tap()
    let copy = app.buttons["copy-grabbernative://timer?preset=1min"]
    XCTAssertTrue(copy.appears(within: 5), app.debugDescription)
    shot(app, "links-screen")
    copy.tap()
    XCTAssertEqual(copy.label, "Copied")
  }
}
