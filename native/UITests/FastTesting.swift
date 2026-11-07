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

extension XCTestCase {
  /// Waits for `predicate` to hold for `object`, looking every 0.1 s, and fails the test at `timeout` as
  /// `waitForExpectations` would. XCTest's predicate expectation looks about once a second, so each of its waits costs
  /// up to a second more than the app takes (story 673).
  func waitUntil(
    _ predicate: NSPredicate, _ object: Any?, timeout: TimeInterval, file: StaticString = #filePath, line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate.evaluate(with: object) {
      guard Date() < deadline else {
        XCTFail("not within \(timeout) s: \(predicate.predicateFormat)", file: file, line: line)
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
  }
}
