//  #686: a menu's rows exist before they stop moving, and a tap in that moment closes the menu or misses, so a choice
//  only sometimes took. These wait for what the tap needs: the element still, and hittable.

import XCTest

extension XCUIElement {
  /// Polls rather than sleeps, so a settled element costs nothing (story 673).
  func settle(timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    while Date() < deadline {
      if exists {
        let now = frame
        if now == last && isHittable { return }
        last = now
      }
      Thread.sleep(forTimeInterval: 0.1)
    }
  }

  func tapWhenSettled(timeout: TimeInterval = 5) {
    settle(timeout: timeout)
    tap()
  }
}
