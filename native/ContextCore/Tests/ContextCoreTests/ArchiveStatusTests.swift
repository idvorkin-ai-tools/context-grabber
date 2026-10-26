//  Story 304: the archive's lines in Settings.

import XCTest

@testable import ContextCore

final class ArchiveStatusTests: XCTestCase {
  private let now: Int64 = 1_780_000_000_000
  private let hour: Int64 = 3_600_000

  private func texts(_ lines: [ArchiveStatus.Line]) -> [String] { lines.map(\.text) }

  func testCaughtUpSaysWhen() {
    let lines = ArchiveStatus.lines(
      sends: true, outcome: ArchiveOutcome(at: now - 2 * hour), lastCaughtUp: now - 2 * hour, now: now)
    XCTAssertEqual(texts(lines), ["Caught up \u{00B7} 2 h ago"])
    XCTAssertFalse(lines[0].trouble)
    let old = ArchiveStatus.lines(
      sends: true, outcome: ArchiveOutcome(at: now - 30 * hour), lastCaughtUp: now - 30 * hour, now: now)
    XCTAssertTrue(old[0].trouble, "no run for over a day")
  }

  func testTheCockpitOutOfReachNamesTheLastTimeItCaughtUp() {
    let outcome = ArchiveOutcome(at: now - 10 * 60_000, stopped: [ArchiveStream.points: "retry"])
    let lines = ArchiveStatus.lines(sends: true, outcome: outcome, lastCaughtUp: now - 50 * hour, now: now)
    XCTAssertEqual(
      texts(lines),
      [
        "Cockpit out of reach \u{00B7} tried 10 min ago \u{00B7} last caught up 2 days ago",
        "Trail: waiting for the Cockpit",
      ])
    XCTAssertTrue(lines[0].trouble, "behind for over a day")
    XCTAssertFalse(
      ArchiveStatus.lines(sends: true, outcome: outcome, lastCaughtUp: now - hour, now: now)[0].trouble,
      "a short spell away is not trouble yet")
  }

  func testARefusedStreamIsRedWithItsStatus() {
    let outcome = ArchiveOutcome(
      at: now - hour,
      stopped: ["strip.balloons": "refused", "health.HKQuantityTypeIdentifierHeartRate": "pages"],
      refused: ["strip.balloons": 404])
    let lines = ArchiveStatus.lines(sends: true, outcome: outcome, lastCaughtUp: nil, now: now)
    XCTAssertEqual(
      texts(lines),
      [
        "Behind \u{00B7} last run 1 h ago \u{00B7} never caught up",
        "Heart Rate: still sending its history",
        "Strip: balloons: refused (404); the rest waits on the phone",
      ])
    XCTAssertEqual(lines.map(\.trouble), [true, false, true])
  }

  func testNotRunYetAndNoArchive() {
    XCTAssertEqual(texts(ArchiveStatus.lines(sends: true, outcome: nil, lastCaughtUp: nil, now: now)), ["Not run yet"])
    XCTAssertEqual(
      texts(ArchiveStatus.lines(sends: false, outcome: nil, lastCaughtUp: nil, now: now)),
      ["Not sent: this build has no archive address"])
  }

  func testNamesAndAges() {
    XCTAssertEqual(ArchiveStatus.name("location.points"), "Trail")
    XCTAssertEqual(ArchiveStatus.name("health.HKCategoryTypeIdentifierSleepAnalysis"), "Sleep Analysis")
    XCTAssertEqual(ArchiveStatus.name("health.HKWorkoutTypeIdentifier"), "Workouts")
    XCTAssertEqual(ArchiveStatus.name("health"), "Health")
    XCTAssertEqual(
      ArchiveStatus.name("health.HKQuantityTypeIdentifierHeartRateVariabilitySDNN"), "Heart Rate Variability SDNN")
    XCTAssertEqual(ArchiveStatus.ago(now - 20_000, now: now), "just now")
    XCTAssertEqual(ArchiveStatus.ago(now - 47 * hour, now: now), "47 h ago")
    XCTAssertEqual(ArchiveStatus.ago(now - 72 * hour, now: now), "3 days ago")
  }

  func testTheOutcomeRoundTripsThroughItsSetting() {
    let outcome = ArchiveOutcome(at: 5, stopped: ["a": "refused"], refused: ["a": 413])
    XCTAssertEqual(ArchiveOutcome(json: outcome.json), outcome)
    XCTAssertNil(ArchiveOutcome(json: nil))
    XCTAssertNil(ArchiveOutcome(json: "not json"))
  }
}
