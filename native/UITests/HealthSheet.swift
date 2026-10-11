//  Health's access sheet, answered the one way that has worked on iOS 27 (the smoke's HealthAccessUITests): Select
//  All, swipe until the identified Allow button is hittable, and on the second page share all history, then Allow.
//  simctl cannot grant Health, so every test that needs it goes through here (#215).

import XCTest

enum HealthSheet {
  /// Answers the sheet in `app` until `done()` holds or `attempts` run out; true when `done()` held.
  @discardableResult
  static func allow(in app: XCUIApplication, attempts: Int = 6, until done: () -> Bool) -> Bool {
    // The sheet's "Select All N Topics" row: the cell carries the identifier, its text carries the label.
    let selectAll = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Select All'")).firstMatch
    let allow = app.buttons["UIA.Health.Allow.Button"]
    for _ in 0..<attempts {
      if done() { return true }
      if selectAll.waitForExistence(timeout: 20), selectAll.isHittable { selectAll.tap() }
      for _ in 0..<4 { app.swipeUp(velocity: .fast) }
      if allow.waitForExistence(timeout: 5) {
        var swipes = 0
        while !allow.isHittable, swipes < 20 {
          app.swipeUp(velocity: .fast)
          swipes += 1
        }
        sleep(1)
        if allow.isHittable { allow.tap() }
        sleep(2)
      }
      // iOS 27 adds a second page: how much history to share. All of it, then Allow.
      let allHistory = app.staticTexts["All Recorded Data and Future Data"]
      let finalAllow = app.buttons.matching(NSPredicate(format: "label == 'Allow'")).firstMatch
      if allHistory.waitForExistence(timeout: 5) {
        allHistory.tap()
        if finalAllow.waitForExistence(timeout: 5), finalAllow.isEnabled { finalAllow.tap() }
      }
      sleep(2)
    }
    return done()
  }
}
