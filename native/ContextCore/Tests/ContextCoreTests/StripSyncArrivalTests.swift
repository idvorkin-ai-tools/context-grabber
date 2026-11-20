import XCTest

@testable import ContextCore

/// #388, story 153: a failed peer write skips only its own key and is retried, and an older build's republish keeps
/// the items it doesn't know. A SQLite trigger stands in for the phone's refusing database (as in #384's tests).
final class StripSyncArrivalTests: XCTestCase {
  private let me = "phone"
  private var db: SQLiteDatabase!
  private var strip: DailyStrip!

  override func setUpWithError() throws {
    db = try SQLiteDatabase(path: ":memory:")
    strip = try DailyStrip(db: db)
  }

  /// Every write of `device`'s peer rows fails, as a refusing database would; others still land.
  private func refusePeer(_ device: String) throws {
    for op in ["INSERT", "UPDATE"] {
      try db.execute(
        """
        CREATE TRIGGER refuse_\(device)_\(op) BEFORE \(op) ON daily_strip_peers WHEN NEW.device = '\(device)'
        BEGIN SELECT RAISE(ABORT, 'refused'); END;
        """)
    }
  }

  private func acceptPeer(_ device: String) throws {
    for op in ["INSERT", "UPDATE"] { try db.execute("DROP TRIGGER refuse_\(device)_\(op);") }
  }

  private func month(_ rows: [StripRow]) -> Data { StripSync.encode(rows)["2026-10"]! }

  private lazy var cloud: [String: Data] = [
    StripSync.key(device: "ipad", month: "2026-10"): month([
      StripRow(day: "2026-10-17", item: .balloons, value: 2, updatedAt: 10),
      StripRow(day: "2026-10-18", item: .gym, value: 1, updatedAt: 11),
    ]),
    StripSync.key(device: "mac", month: "2026-10"): month([
      StripRow(day: "2026-10-17", item: .balloons, value: 1, updatedAt: 12)
    ]),
    StripSync.key(device: me, month: "2026-10"): month([
      StripRow(day: "2026-10-17", item: .magic, value: 4, updatedAt: 13)
    ]),
    StripSync.key(device: "ipad", month: "2025-01"): Data("{}".utf8),
    "something.else": Data("x".utf8),
  ]

  private func absorb(_ keys: [String]? = nil) -> StripArrival {
    strip.absorb(keys: keys ?? Array(cloud.keys), device: me, oldest: "2025-11") { self.cloud[$0] }
  }

  // MARK: item 2, a failed peer write

  /// One device's refused month skips only that key: the others land, and the failure names it.
  func testARefusedPeerKeySkipsOnlyItself() throws {
    try refusePeer("ipad")
    let arrival = absorb()
    XCTAssertEqual(arrival.merged, ["mac": ["2026-10"], me: ["2026-10"]])
    XCTAssertEqual(Array(arrival.failed.keys), [StripSync.key(device: "ipad", month: "2026-10")])
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-17"), 1, "the Mac's balloon arrived, not the iPad's")
    XCTAssertEqual(try strip.ownValue(.magic, day: "2026-10-17"), 4, "this device's own month came back too")
  }

  /// A refused key is all or nothing: a month refused halfway keeps none of its rows, so a re-read lands it whole.
  func testARefusedKeyLeavesNoHalfMonthAndAReReadLandsIt() throws {
    try db.execute(
      """
      CREATE TRIGGER refuse_gym BEFORE INSERT ON daily_strip_peers WHEN NEW.item = 'gym'
      BEGIN SELECT RAISE(ABORT, 'refused'); END;
      """)
    let key = StripSync.key(device: "ipad", month: "2026-10")
    XCTAssertEqual(Array(absorb([key]).failed.keys), [key])
    XCTAssertEqual(
      try strip.value(.balloons, day: "2026-10-17"), 0, "the balloon row before the refused one rolled back")
    try db.execute("DROP TRIGGER refuse_gym;")
    let again = absorb()
    XCTAssertEqual(again.failed, [:])
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-17"), 3)
    XCTAssertEqual(try strip.value(.gym, day: "2026-10-18"), 1)
  }

  /// The re-read the app does on coming to the front picks up the key that failed, without it changing again.
  func testAFullReReadPicksUpTheMissedKey() throws {
    try refusePeer("ipad")
    XCTAssertFalse(absorb().failed.isEmpty)
    try acceptPeer("ipad")
    let again = absorb()
    XCTAssertEqual(again.failed, [:])
    XCTAssertEqual(again.merged["ipad"], ["2026-10"])
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-17"), 3)
  }

  /// Months older than iCloud carries, keys that left and keys that aren't the strip's are passed over.
  func testOldMissingAndForeignKeysArePassedOver() {
    let arrival = absorb(["something.else", StripSync.key(device: "ipad", month: "2025-01"), "strip.gone.2026-10"])
    XCTAssertEqual(arrival.merged, [:])
    XCTAssertEqual(arrival.failed, [:])
  }

  // MARK: item 3, items this build doesn't know

  /// Republishing a month keeps the entries of items this build doesn't know, beside its own new rows.
  func testRepublishCarriesUnknownItemsThrough() throws {
    let old = Data(
      #"{"2026-10-17":{"balloons":[3,1],"unicorns":[2,5]},"2026-10-18":{"unicorns":[1,6],"gym":[1,7]}}"#.utf8)
    let new = month([StripRow(day: "2026-10-17", item: .balloons, value: 4, updatedAt: 9)])
    let out = StripSync.carryingUnknown(new, from: old)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: out) as? [String: [String: [Int]]])
    XCTAssertEqual(
      json,
      [
        "2026-10-17": ["balloons": [4, 9], "unicorns": [2, 5]],
        "2026-10-18": ["unicorns": [1, 6]],
      ], "the unknown item stays; a known item this device no longer holds is its own to drop")
  }

  /// With nothing in iCloud, or nothing unknown in it, the month goes up as this build wrote it.
  func testNothingUnknownLeavesTheMonthAsWritten() {
    let new = month([StripRow(day: "2026-10-17", item: .balloons, value: 4, updatedAt: 9)])
    XCTAssertEqual(StripSync.carryingUnknown(new, from: nil), new)
    XCTAssertEqual(StripSync.carryingUnknown(new, from: Data("nope".utf8)), new)
    XCTAssertEqual(StripSync.carryingUnknown(new, from: Data(#"{"2026-10-17":{"gym":[1,2]}}"#.utf8)), new)
  }
}
