import XCTest

@testable import ContextCore

/// Story 1311 (context-grabber-7xv6): the board's Pencil-to-frame latency, summed up for the session log.
final class PenLatencyTests: XCTestCase {
  func testSummaryIsNearestRankPercentilesInTenthsOfAMillisecond() {
    let ms = (1...10).map { Double($0) + 0.04 }  // 1.04 ... 10.04
    let summary = PenLatency.summary(ms)
    XCTAssertEqual(summary, PenLatency.Summary(count: 10, p50: 5.0, p90: 9.0, slowest: 10.0))
  }

  func testNoMomentsNoSummary() {
    XCTAssertNil(PenLatency.summary([]))
  }

  func testOneMomentInFourIsMeasured() {
    var meter = PenLatency()
    let picked = (0..<12).map { _ in meter.measuresNext() }
    XCTAssertEqual(picked, [true, false, false, false, true, false, false, false, true, false, false, false])
  }

  func testTwoHundredMomentsMakeALine() {
    var meter = PenLatency()
    for i in 0..<199 { XCTAssertNil(meter.add(milliseconds: Double(i % 20))) }
    let line = meter.add(milliseconds: 8)
    XCTAssertEqual(line?.count, 200)
    XCTAssertEqual(meter.pending, 0)
  }

  func testALiftAfterTwentyMakesALineAndFewerCarryOver() {
    var meter = PenLatency()
    for _ in 0..<19 { _ = meter.add(milliseconds: 12) }
    XCTAssertNil(meter.lifted())
    XCTAssertEqual(meter.pending, 19)
    _ = meter.add(milliseconds: 12)
    XCTAssertEqual(meter.lifted(), PenLatency.Summary(count: 20, p50: 12, p90: 12, slowest: 12))
    XCTAssertEqual(meter.pending, 0)
  }

  func testAMomentOutsideASecondIsDropped() {
    var meter = PenLatency()
    _ = meter.add(milliseconds: -1)
    _ = meter.add(milliseconds: 1500)
    XCTAssertEqual(meter.pending, 0)
  }
}
