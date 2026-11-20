import XCTest

@testable import ContextCore

/// #384, story 153: the strip sync when the database refuses a write. A SQLite trigger stands in for the phone's
/// refusing database, so the real statements fail where they would on the device.
final class StripSyncWriteFailureTests: XCTestCase {
  private let day = "2026-10-17"
  private var db: SQLiteDatabase!
  private var strip: DailyStrip!
  private var settings: SettingsStore!

  override func setUpWithError() throws {
    db = try SQLiteDatabase(path: ":memory:")
    strip = try DailyStrip(db: db)
    settings = try SettingsStore(db: db)
  }

  /// Every insert and update into `table` fails, as a full or read-only database would.
  private func refuse(_ table: String) throws {
    for op in ["INSERT", "UPDATE"] {
      try db.execute(
        "CREATE TRIGGER refuse_\(table)_\(op) BEFORE \(op) ON \(table) BEGIN SELECT RAISE(ABORT, 'refused'); END;")
    }
  }

  private func accept(_ table: String) throws {
    for op in ["INSERT", "UPDATE"] { try db.execute("DROP TRIGGER refuse_\(table)_\(op);") }
  }

  /// A recovery of this device's own iCloud months, all or nothing, reported to the gate as the app does.
  private func recover(_ gate: inout StripPublishGate, _ rows: [StripRow]) {
    do {
      try strip.inTransaction { try strip.mergeOwn(rows) }
      gate.recovery(succeeded: true)
    } catch {
      gate.recovery(succeeded: false)
    }
  }

  private let cloud = [StripRow(day: "2026-10-17", item: .balloons, value: 3, updatedAt: 9_000_000_000_000)]

  // MARK: finding 1, a ready device whose launch recovery fails

  /// A ready database whose launch recovery is refused sends nothing: a tap retries the recovery first, and once it
  /// succeeds every month goes up, the tapped one included.
  func testAFailedLaunchRecoveryClosesPublishingUntilARetrySucceeds() throws {
    try strip.set(.balloons, day: day, value: 1, at: Date(timeIntervalSince1970: 1_000))
    var gate = StripPublishGate(ready: true)
    XCTAssertEqual(gate.tap(day: day), .publish(month: "2026-10"))
    try refuse("daily_strip")
    recover(&gate, cloud)
    XCTAssertFalse(gate.publishes)
    XCTAssertEqual(gate.tap(day: day), .recoverFirst)
    recover(&gate, cloud)  // still refused: still closed
    XCTAssertEqual(gate.tap(day: day), .recoverFirst)
    XCTAssertEqual(try strip.ownValue(.balloons, day: day), 1, "nothing half-merged")
    try accept("daily_strip")
    recover(&gate, cloud)
    XCTAssertTrue(gate.publishes)
    XCTAssertEqual(gate.tap(day: day), .publish(month: "2026-10"))
    XCTAssertEqual(try strip.ownValue(.balloons, day: day), 3, "iCloud's newer own count came back before publishing")
  }

  /// A refused write while another device's months arrive closes publishing too, however the launch went.
  func testAFailedArrivalClosesPublishingUntilARecoverySucceeds() throws {
    var gate = StripPublishGate(ready: true)
    try refuse("daily_strip_peers")
    XCTAssertThrowsError(try strip.mergePeer("ipad", month: "2026-10", rows: cloud))
    gate.arrivalFailed()
    XCTAssertEqual(gate.tap(day: day), .recoverFirst)
    recover(&gate, cloud)
    XCTAssertEqual(gate.tap(day: day), .publish(month: "2026-10"))
  }

  /// A database waiting for its first sync holds a tap's month; the first sync opens it whatever came before.
  func testAWaitingDatabaseHoldsTapsUntilTheFirstSync() {
    var gate = StripPublishGate(ready: false)
    gate.arrivalFailed()
    XCTAssertFalse(gate.publishes)
    XCTAssertEqual(gate.tap(day: day), .hold(month: "2026-10"))
    gate.opened()
    XCTAssertTrue(gate.publishes)
    XCTAssertEqual(gate.tap(day: day), .publish(month: "2026-10"))
  }

  // MARK: finding 2, a held step and its counter write are one transaction

  /// Waiting for the first sync, a tap whose counter write is refused holds no step, so the retried tap counts once.
  func testARefusedCounterWriteHoldsNoStepSoARetryCountsOnce() throws {
    let held = StripHeldSteps(strip: strip, settings: settings)
    try refuse("daily_strip")
    XCTAssertThrowsError(try held.step(.balloons, day: day, by: 1, holding: true))
    XCTAssertEqual(try held.all(), [:], "the refused tap left nothing to replay")
    try accept("daily_strip")
    XCTAssertEqual(try held.step(.balloons, day: day, by: 1, holding: true), 1)
    XCTAssertEqual(try held.all()["\(day)/balloons"]?.net, 1)
    XCTAssertEqual(try strip.ownValue(.balloons, day: day), 1)
  }

  /// The other way round: a refused held-step write leaves the count as it was, so the step is never lost from the
  /// replay while the count keeps it.
  func testARefusedHeldStepLeavesTheCountAsItWas() throws {
    let held = StripHeldSteps(strip: strip, settings: settings)
    XCTAssertEqual(try held.step(.magic, day: day, by: 1, holding: true), 1)
    try refuse("settings")
    XCTAssertThrowsError(try held.step(.magic, day: day, by: 1, holding: true))
    XCTAssertEqual(try strip.ownValue(.magic, day: day), 1)
    XCTAssertEqual(try held.all()["\(day)/magic"]?.net, 1)
  }

  /// A held step keeps the row as it was before the first step, and sums every step after it; a − at 0 holds 0.
  func testHeldStepsKeepTheOriginalRowAndTheirSum() throws {
    try strip.set(.balloons, day: day, value: 2, at: Date(timeIntervalSince1970: 1))
    let held = StripHeldSteps(strip: strip, settings: settings)
    XCTAssertEqual(try held.step(.balloons, day: day, by: 1, holding: true), 3)
    XCTAssertEqual(try held.step(.balloons, day: day, by: 1, holding: true), 4)
    XCTAssertEqual(try held.step(.magic, day: day, by: -1, holding: true), 0)
    let all = try held.all()
    XCTAssertEqual(all["\(day)/balloons"], StripHeldStep(item: "balloons", day: day, original: [2, 1_000], net: 2))
    XCTAssertEqual(all["\(day)/magic"], StripHeldStep(item: "magic", day: day, original: nil, net: 0))
    try held.clear()
    XCTAssertEqual(try held.all(), [:])
  }

  /// Once synced nothing is held: the step is only the counter write.
  func testAReadyStepHoldsNothing() throws {
    let held = StripHeldSteps(strip: strip, settings: settings)
    XCTAssertEqual(try held.step(.balloons, day: day, by: 1, holding: false), 1)
    XCTAssertEqual(try held.all(), [:])
  }
}
