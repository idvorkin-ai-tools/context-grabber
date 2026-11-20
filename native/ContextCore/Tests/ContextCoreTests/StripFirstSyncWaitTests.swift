import XCTest

@testable import ContextCore

/// #388 item 1, option A (Igor, 2026-11-19), story 153: iCloud's first delivery may be partial, so a reinstall waits
/// for a minute online in the foreground with nothing more arriving; with nothing arriving at all, five minutes.
final class StripFirstSyncWaitTests: XCTestCase {
  private let t0 = Date(timeIntervalSince1970: 1_000_000)
  private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

  /// Nothing arrives: five minutes online in the foreground end the wait, as before.
  func testWithNoArrivalFiveQuietMinutesEndTheWait() {
    var wait = StripFirstSyncWait()
    wait.counting(true, at: t0)
    XCTAssertEqual(wait.deadline, at(300))
    XCTAssertEqual(wait.why, "online_quiet")
    XCTAssertNil(wait.after)
  }

  /// An arrival no longer opens at once: a minute with nothing more does, and each later arrival starts it again.
  func testEachArrivalStartsAFreshMinute() {
    var wait = StripFirstSyncWait()
    wait.counting(true, at: t0)
    wait.arrived("initial_sync", at: at(10))
    XCTAssertEqual(wait.deadline, at(70))
    wait.arrived("server_change", at: at(50))
    XCTAssertEqual(wait.deadline, at(110), "the second part of the download kept it waiting")
    XCTAssertEqual(wait.why, "settled")
    XCTAssertEqual(wait.after, "initial_sync", "the arrival that started the wait")
  }

  /// Offline or in the background no time counts, and coming back starts the minute over.
  func testOfflineTimeNeverCounts() {
    var wait = StripFirstSyncWait()
    wait.counting(true, at: t0)
    wait.arrived("initial_sync", at: at(10))
    wait.counting(false, at: at(30))
    XCTAssertNil(wait.deadline)
    wait.counting(true, at: at(200))
    XCTAssertEqual(wait.deadline, at(260))
  }

  /// An arrival seen before time counts settles from when it starts counting.
  func testAnArrivalBeforeCountingSettlesFromWhenCountingStarts() {
    var wait = StripFirstSyncWait()
    wait.arrived("store_holds", at: t0)
    XCTAssertNil(wait.deadline)
    wait.counting(true, at: at(5))
    XCTAssertEqual(wait.deadline, at(65))
  }

  /// Being told again that time counts (a second network update, coming to the front while there) moves nothing.
  func testARepeatedOnMovesNothing() {
    var wait = StripFirstSyncWait()
    wait.counting(true, at: t0)
    wait.counting(true, at: at(100))
    XCTAssertEqual(wait.deadline, at(300))
  }
}
