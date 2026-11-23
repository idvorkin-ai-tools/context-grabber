//  Story 1135 (bead context-grabber-97s): the card at the top of a thread stops at about 60% of it and scrolls inside.

import ContextCore
import XCTest

final class ChatDecisionCapTests: XCTestCase {
  func testTheBodyIsHalfTheThreadSoTheCardWithItsHeadingIsAboutSixtyPercent() {
    XCTAssertEqual(ChatDecisions.threadCardBodyCap(threadHeight: 1000), 500)
    XCTAssertEqual(ChatDecisions.threadCardBodyCap(threadHeight: 640), 320)
  }

  func testAShortThreadStillShowsAFewLines() {
    XCTAssertEqual(ChatDecisions.threadCardBodyCap(threadHeight: 180), ChatDecisions.threadCardBodyFloor)
  }

  func testAnUnmeasuredThreadLeavesTheCardUnbounded() {
    XCTAssertNil(ChatDecisions.threadCardBodyCap(threadHeight: 0))
    XCTAssertNil(ChatDecisions.threadCardBodyCap(threadHeight: -1))
  }
}
