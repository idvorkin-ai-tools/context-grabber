//  Story 1168 (bead context-grabber-uktm): a slow change to the ink names its slow parts; a quick one says nothing.

import XCTest

@testable import ContextCore

final class StepLapsTests: XCTestCase {
  /// A clock that reads each value in turn, in seconds.
  private func clock(_ readings: [Double]) -> StepLaps.Clock {
    var next = readings.makeIterator()
    return { next.next() ?? readings.last ?? 0 }
  }

  /// The iPad's 1,475 ms stroke (2026-11-22, board 8f986938): 50 ms of frames, then 1,400 ms in one part.
  func testASlowChangeNamesEachPart() throws {
    let laps = StepLaps(clock: clock([0, 0.05, 0.05, 1.45, 1.47, 1.475]))
    laps.lap("frames")
    _ = laps.time("tap_dot") { false }
    laps.lap("model")
    let slow = try XCTUnwrap(laps.report(overMs: 250))
    XCTAssertEqual(slow.totalMs, 1475)
    XCTAssertEqual(slow.laps, ["frames": 50, "tap_dot": 1400, "model": 20])
  }

  func testAQuickChangeSaysNothing() {
    let laps = StepLaps(clock: clock([0, 0.02, 0.049]))
    laps.lap("frames")
    XCTAssertNil(laps.report(overMs: 250))
  }

  func testTheThresholdItselfIsSlow() {
    let laps = StepLaps(clock: clock([0, 0.25]))
    XCTAssertEqual(laps.report(overMs: 250)?.totalMs, 250)
  }

  func testANameUsedTwiceAddsUpAndUnnamedTimeIsOther() throws {
    let laps = StepLaps(clock: clock([0, 0.1, 0.3, 0.4, 0.6, 0.7, 0.9, 0.9]))
    laps.lap("frames")  // 100
    _ = laps.time("scratch") { true }  // other 200, scratch 100
    laps.lap("frames")  // 200 more
    _ = laps.time("scratch") { true }  // other 100, scratch 200
    let slow = try XCTUnwrap(laps.report(overMs: 0))
    XCTAssertEqual(slow.laps, ["frames": 300, "other": 300, "scratch": 300])
    XCTAssertEqual(laps.laps.map(\.name), ["frames", "other", "scratch"])
  }

  func testTimeReturnsWhatItsBodyReturns() {
    let laps = StepLaps(clock: clock([0]))
    XCTAssertEqual(laps.time("x") { 7 }, 7)
  }
}
