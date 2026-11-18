import XCTest

@testable import ContextCore

/// #946: "I think I just hung." The log went silent for 14 s with nothing to say whether the main thread was stuck.
final class MainStallMeterTests: XCTestCase {
  func testAMainThreadThatKeepsAnsweringSaysNothing() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    for tick in 1...20 {
      let now = Double(tick) * 0.25
      XCTAssertNil(meter.checked(at: now))
      XCTAssertNil(meter.answered(at: now))
    }
  }

  func testAStallIsSaidOnceWhenItPassesTheThresholdAndAgainWhenItEnds() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertNil(meter.answered(at: 0.25))
    XCTAssertNil(meter.checked(at: 0.5))
    XCTAssertNil(meter.checked(at: 1.0))
    XCTAssertEqual(meter.checked(at: 1.25), .began(waited: 1.0))
    // Still stuck: no second "began".
    XCTAssertNil(meter.checked(at: 5))
    XCTAssertNil(meter.checked(at: 14))
    XCTAssertEqual(meter.answered(at: 14.75), .ended(lasted: 14.5))
    // Answering again: back to quiet.
    XCTAssertNil(meter.checked(at: 15))
    XCTAssertNil(meter.answered(at: 15))
  }

  func testAHitchUnderTheThresholdSaysNothing() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertNil(meter.checked(at: 0.9))
    XCTAssertNil(meter.answered(at: 0.95))
  }

  func testRestartingAfterTheAppWasAwayIsNoStall() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    // Suspended for a minute: the watch restarts on coming back, so the gap isn't a stall.
    meter.restart(at: 60)
    XCTAssertNil(meter.checked(at: 60.25))
    XCTAssertNil(meter.answered(at: 60.25))
  }

  func testStoppingInAStallEndsIt() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertEqual(meter.checked(at: 2), .began(waited: 2))
    // The main thread comes back to the app going inactive before it reaches the watch's own answer.
    XCTAssertEqual(meter.stopped(at: 9), .ended(lasted: 9))
    XCTAssertNil(meter.stopped(at: 9.5))
    meter.restart(at: 30)
    XCTAssertNil(meter.answered(at: 30.1))
  }
}
