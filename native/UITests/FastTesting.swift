//  What keeps the UI tests quick (story 673).

import XCTest

extension XCUIElement {
  /// Like `waitForExistence`, whose first look comes about a second in even when the element is already there.
  func appears(within timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if exists { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return exists
  }
}
