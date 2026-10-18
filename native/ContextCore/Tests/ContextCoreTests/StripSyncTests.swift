import XCTest

@testable import ContextCore

/// #376, story 153: the strip across devices. Counts add up, a check is its latest change, and each device's
/// months travel as their own keys.
final class StripSyncTests: XCTestCase {
  private func strip() throws -> DailyStrip { try DailyStrip(db: SQLiteDatabase(path: ":memory:")) }
  private let day = "2026-10-17"

  func testCountsAddUpAcrossDevices() throws {
    let s = try strip()
    try s.set(.balloons, day: day, value: 2)
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .balloons, value: 1, updatedAt: 5)])
    XCTAssertEqual(try s.value(.balloons, day: day), 3)
    XCTAssertEqual(try s.ownValue(.balloons, day: day), 2, "a step starts from this device's own count")
  }

  func testACheckFromAnotherDeviceCountsHereAndInDaysSince() throws {
    let s = try strip()
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .journal, value: 1, updatedAt: 5)])
    XCTAssertEqual(try s.value(.journal, day: day), 1)
    XCTAssertEqual(try s.days(.journal), [day])
  }

  func testTheLatestChangeToACheckWinsSoAnyDeviceCanUntickIt() throws {
    let s = try strip()
    try s.set(.journal, day: day, value: 1, at: Date(timeIntervalSince1970: 100))
    try s.mergePeer(
      "ipad", month: "2026-10", rows: [StripRow(day: day, item: .journal, value: 0, updatedAt: 200_000)])
    XCTAssertEqual(try s.value(.journal, day: day), 0, "the iPad unticked it after the phone ticked it")
    try s.set(.journal, day: day, value: 1, at: Date(timeIntervalSince1970: 300))
    XCTAssertEqual(try s.value(.journal, day: day), 1, "and a later tick here wins again")
  }

  func testAPeersNewerValueReplacesItsOlderOneNotAddsToIt() throws {
    let s = try strip()
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .magic, value: 4, updatedAt: 1)])
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .magic, value: 1, updatedAt: 2)])
    XCTAssertEqual(try s.value(.magic, day: day), 1)
    try s.mergePeer("ipad", month: "2026-10", rows: [])
    XCTAssertEqual(try s.value(.magic, day: day), 1, "an arriving month never deletes")
  }

  /// Local review: a restore held a count the old phone never uploaded; its older month arriving must not undo it.
  func testAnOlderMonthArrivingKeepsTheNewerHandedOverCount() throws {
    let s = try strip()
    try s.set(.balloons, day: day, value: 3, at: Date(timeIntervalSince1970: 200))
    try s.handOver(to: "old-phone")
    try s.mergePeer(
      "old-phone", month: "2026-10", rows: [StripRow(day: day, item: .balloons, value: 1, updatedAt: 100_000)])
    XCTAssertEqual(try s.value(.balloons, day: day), 3)
  }

  func testOwnRowsByMonthCarryWhenTheyChanged() throws {
    let s = try strip()
    try s.set(.gym, day: "2026-09-30", value: 1, at: Date(timeIntervalSince1970: 1))
    try s.set(.gym, day: day, value: 1, at: Date(timeIntervalSince1970: 2))
    XCTAssertEqual(try s.ownRows().count, 2)
    XCTAssertEqual(try s.ownRows(month: "2026-10"), [StripRow(day: day, item: .gym, value: 1, updatedAt: 2000)])
  }

  func testAStripFromBeforeSyncGainsItsColumnAndKeepsItsDays() throws {
    let db = try SQLiteDatabase(path: ":memory:")
    try db.execute(
      "CREATE TABLE daily_strip (date_key TEXT NOT NULL, item TEXT NOT NULL, value INTEGER NOT NULL, PRIMARY KEY (date_key, item));"
    )
    _ = try db.run("INSERT INTO daily_strip VALUES (?, 'journal', 1)", [.text(day)])
    let s = try DailyStrip(db: db)
    XCTAssertEqual(try s.ownRows(), [StripRow(day: day, item: .journal, value: 1, updatedAt: 0)])
    XCTAssertEqual(try s.days(.journal), [day])
  }

  func testMonthsRoundTripThroughTheirKeys() {
    let rows = [
      StripRow(day: "2026-09-30", item: .gym, value: 1, updatedAt: 7),
      StripRow(day: day, item: .balloons, value: 3, updatedAt: 9),
    ]
    let months = StripSync.encode(rows)
    XCTAssertEqual(Set(months.keys), ["2026-09", "2026-10"])
    let back = months.values.flatMap(StripSync.decode).sorted { $0.day < $1.day }
    XCTAssertEqual(back, rows)
  }

  /// Codex on #378: iCloud carries a year, so ten years on two devices stays far under the 1 MB quota.
  func testICloudCarriesTwelveMonths() {
    XCTAssertEqual(StripSync.oldestKept(today: "2026-10-17"), "2025-11")
    XCTAssertEqual(StripSync.oldestKept(today: "2026-12-01"), "2026-01")
    XCTAssertEqual(StripSync.oldestKept(today: "2026-01-31"), "2025-02")
  }

  func testAFullYearOfEveryItemEveryDayFitsEasily() {
    var rows: [StripRow] = []
    for m in 1...12 {
      for d in 1...31 {
        for item in DailyItem.allCases {
          rows.append(
            StripRow(day: String(format: "2026-%02d-%02d", m, d), item: item, value: 12, updatedAt: 1_760_000_000_000))
        }
      }
    }
    let bytes = StripSync.encode(rows).values.reduce(0) { $0 + $1.count }
    XCTAssertLessThan(bytes * 4, 1_000_000 / 2, "four devices' years use under half the quota")
  }

  func testKeysNameTheirDeviceAndMonth() {
    let key = StripSync.key(device: "A1B2-C3", month: "2026-10")
    XCTAssertEqual(key, "strip.A1B2-C3.2026-10")
    XCTAssertEqual(StripSync.parse(key: key)?.device, "A1B2-C3")
    XCTAssertEqual(StripSync.parse(key: key)?.month, "2026-10")
    XCTAssertNil(StripSync.parse(key: "other.key"))
    XCTAssertNil(StripSync.parse(key: "strip.2026-10"))
  }

  func testAMalformedValueDecodesToNothing() {
    XCTAssertEqual(StripSync.decode(Data("nope".utf8)), [])
    XCTAssertEqual(StripSync.decode(Data(#"{"2026-10-17":{"unicorns":[1,2],"gym":[1]}}"#.utf8)), [])
  }

  /// Codex on #378: one bad or unknown entry must not cost the month its good ones.
  func testOneBadEntrySkipsOnlyItself() {
    let data = Data(#"{"2026-10-17":{"gym":[1,123],"futureItem":"bad","journal":"x"},"2026-10-16":7}"#.utf8)
    XCTAssertEqual(StripSync.decode(data), [StripRow(day: "2026-10-17", item: .gym, value: 1, updatedAt: 123)])
  }

  /// A restore onto a new phone: the history it carried is the old phone's, shown once, and a tap here adds to it.
  func testARestoredHistoryIsHandedToTheOldPhoneAndCountsOnce() throws {
    let s = try strip()
    try s.set(.balloons, day: day, value: 2, at: Date(timeIntervalSince1970: 1))
    try s.set(.journal, day: day, value: 1, at: Date(timeIntervalSince1970: 1))
    XCTAssertEqual(try s.handOver(to: "old-phone"), 2)
    XCTAssertEqual(try s.ownRows(), [])
    XCTAssertEqual(try s.value(.balloons, day: day), 2)
    XCTAssertEqual(try s.value(.journal, day: day), 1)
    // The old phone's own keys then arrive with the same month: replaced, not added.
    try s.mergePeer(
      "old-phone", month: "2026-10", rows: [StripRow(day: day, item: .balloons, value: 2, updatedAt: 1000)])
    try s.set(.balloons, day: day, value: 1)
    XCTAssertEqual(try s.value(.balloons, day: day), 3)
  }

  /// Local review: a reinstall starts empty under the same vendor id; its iCloud months come back, newer only.
  func testThisDevicesOwnICloudRowsComeBackWhereNewer() throws {
    let s = try strip()
    try s.set(.journal, day: day, value: 0, at: Date(timeIntervalSince1970: 500))
    try s.mergeOwn([
      StripRow(day: day, item: .journal, value: 1, updatedAt: 100_000),
      StripRow(day: day, item: .magic, value: 2, updatedAt: 100_000),
    ])
    XCTAssertEqual(try s.value(.journal, day: day), 0, "the newer local untick stays")
    XCTAssertEqual(try s.value(.magic, day: day), 2)
  }

  func testClearingPeersLeavesThisDevicesOwn() throws {
    let s = try strip()
    try s.set(.magic, day: day, value: 1)
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .magic, value: 2, updatedAt: 1)])
    try s.clearPeers()
    XCTAssertEqual(try s.value(.magic, day: day), 1)
  }

  /// A restored phone signs out of iCloud later: the history it carried is not in any store, so it stays.
  func testAnAccountChangeKeepsTheHistoryHandedOver() throws {
    let s = try strip()
    try s.set(.gym, day: "2026-09-30", value: 1, at: Date(timeIntervalSince1970: 1))
    try s.handOver(to: "old-phone")
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: day, item: .gym, value: 1, updatedAt: 1)])
    try s.clearPeers(keeping: ["old-phone"])
    XCTAssertEqual(try s.days(.gym), ["2026-09-30"])
  }
}
