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
    // Still stuck, the watch looking every quarter second: no second "began".
    for tick in 6...56 { XCTAssertNil(meter.checked(at: Double(tick) * 0.25)) }
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
    XCTAssertNil(meter.checked(at: 0.25))
    XCTAssertNil(meter.stopped(at: 0.5))
    XCTAssertNil(meter.answered(at: 59.5))
    XCTAssertNil(meter.checked(at: 59.75))
    meter.restart(at: 60)
    XCTAssertNil(meter.checked(at: 60.25))
    XCTAssertNil(meter.answered(at: 60.25))
  }

  func testStoppingInAStallEndsIt() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertEqual(meter.checked(at: 2), .began(waited: 2))
    for tick in 9...35 { XCTAssertNil(meter.checked(at: Double(tick) * 0.25)) }
    // The main thread comes back to the app going inactive before it reaches the watch's own answer.
    XCTAssertEqual(meter.stopped(at: 9), .ended(lasted: 9))
    XCTAssertNil(meter.stopped(at: 9.5))
    meter.restart(at: 30)
    XCTAssertNil(meter.answered(at: 30.1))
  }

  // Bead context-grabber-55vm: the iPad logged suspended time as stalls (waited_ms 281,422 to 921,354 in
  // grabber-20261120-071137, 1,158,372 in 062630, 2,957,505 in 101810), each the app's time away while the watch's
  // timer, which didn't stop, was asleep with the rest of the process.

  func testAWatchThatWasAsleepWithTheAppSaysAwayNotAStall() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertNil(meter.checked(at: 0.25))
    XCTAssertNil(meter.answered(at: 0.25))
    // Suspended for 921 s: the next look comes 921 s after the last one.
    XCTAssertEqual(meter.checked(at: 921.604), .away(gap: 921.354))
    // The pending answer arriving on resume is no stall either, and the watch carries on quietly.
    XCTAssertNil(meter.answered(at: 921.62))
    XCTAssertNil(meter.checked(at: 921.85))
    XCTAssertNil(meter.answered(at: 921.86))
  }

  func testARealStallKeepsTheWatchLookingSoItIsStillAStall() {
    // The 6.5 s stall at t=4953804 in 071137: the main thread stuck, the watch looking every quarter second.
    var meter = MainStallMeter(threshold: 1, now: 0)
    var began: MainStallMeter.Word?
    var now = 0.0
    while now < 6.5 {
      now += 0.25
      if let word = meter.checked(at: now) { began = began ?? word }
    }
    XCTAssertEqual(began, .began(waited: 1.0))
    XCTAssertEqual(meter.answered(at: 6.5), .ended(lasted: 6.5))
  }

  func testSuspendedMidStallForgetsTheStallAndSaysSo() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertNil(meter.checked(at: 0.75))
    XCTAssertEqual(meter.checked(at: 1.25), .began(waited: 1.25))
    XCTAssertEqual(meter.checked(at: 300), .away(gap: 298.75))
    XCTAssertNil(meter.answered(at: 300.1))
  }

  func testAReplyFirstAfterSuspensionSaysAwayOnce() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertEqual(meter.checked(at: 1.25), .began(waited: 1.25))
    XCTAssertEqual(meter.answered(at: 300), .away(gap: 298.75))
    XCTAssertNil(meter.checked(at: 300.25))
    XCTAssertNil(meter.stopped(at: 300.5))
  }

  func testAStopFirstAfterSuspensionSaysAwayOnce() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertEqual(meter.checked(at: 1.25), .began(waited: 1.25))
    XCTAssertEqual(meter.stopped(at: 300), .away(gap: 298.75))
    XCTAssertNil(meter.answered(at: 300.1))
    XCTAssertNil(meter.checked(at: 300.25))
  }

  func testAGapJustUnderFiveSecondsIsStillWatched() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertEqual(meter.checked(at: 4.999), .began(waited: 4.999))
  }

  func testAGapOfExactlyFiveSecondsIsAway() {
    var meter = MainStallMeter(threshold: 1, now: 0)
    XCTAssertNil(meter.answered(at: 4.999))
    XCTAssertEqual(meter.checked(at: 5), .away(gap: 5))
  }
}
