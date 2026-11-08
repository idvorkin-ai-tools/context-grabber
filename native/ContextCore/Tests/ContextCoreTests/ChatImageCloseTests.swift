import XCTest

@testable import ContextCore

/// Story 306: which drags close a full-size picture.
final class ChatImageCloseTests: XCTestCase {
  func testOnlyASwipeDownPastEightyPointsCloses() {
    XCTAssertTrue(ChatImageClose.closes(dragHeight: 81))
    XCTAssertTrue(ChatImageClose.closes(dragHeight: 600))
    XCTAssertFalse(ChatImageClose.closes(dragHeight: 80), "a short swipe down leaves it")
    XCTAssertFalse(ChatImageClose.closes(dragHeight: 0), "sideways leaves it")
    XCTAssertFalse(ChatImageClose.closes(dragHeight: -200), "a swipe up leaves it")
  }

  func testATapIsNotADrag() {
    XCTAssertEqual(ChatImageClose.minimumDrag, 30)
  }
}
