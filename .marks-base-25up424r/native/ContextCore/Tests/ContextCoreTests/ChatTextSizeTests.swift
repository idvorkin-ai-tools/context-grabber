import XCTest

@testable import ContextCore

/// Story 729: chat's text size on the Mac steps through the system's sizes and stops at either end.
final class ChatTextSizeTests: XCTestCase {
  func testItStartsAtTheSystemsDefaultAndStepsOneSizeAtATime() {
    let start = ChatTextSize.restored(nil)
    XCTAssertEqual(start, ChatTextSize.standard)
    XCTAssertEqual(ChatTextSize.bigger(start), start + 1)
    XCTAssertEqual(ChatTextSize.smaller(start), start - 1)
    XCTAssertEqual(ChatTextSize.smaller(ChatTextSize.bigger(start)), start, "Actual Size is a step back from one up")
  }

  func testItStopsAtTheSmallestAndTheLargest() {
    XCTAssertEqual(ChatTextSize.smaller(0), 0)
    XCTAssertFalse(ChatTextSize.canShrink(0))
    let largest = ChatTextSize.steps - 1
    XCTAssertEqual(ChatTextSize.bigger(largest), largest)
    XCTAssertFalse(ChatTextSize.canGrow(largest))
    XCTAssertTrue(ChatTextSize.canGrow(ChatTextSize.standard))
    XCTAssertTrue(ChatTextSize.canShrink(ChatTextSize.standard))
  }

  func testARememberedSizeComesBackAndANonsenseOneIsTheDefault() {
    XCTAssertEqual(ChatTextSize.restored(7), 7)
    XCTAssertEqual(ChatTextSize.restored(0), 0)
    XCTAssertEqual(ChatTextSize.restored(-1), ChatTextSize.standard)
    XCTAssertEqual(ChatTextSize.restored(ChatTextSize.steps), ChatTextSize.standard)
  }
}
