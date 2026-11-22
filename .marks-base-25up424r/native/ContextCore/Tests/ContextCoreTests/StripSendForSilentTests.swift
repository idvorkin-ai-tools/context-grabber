import XCTest

@testable import ContextCore

/// #379, story 154: a restore's never-sent changes, handed to the old phone's id, go up under its keys once it has
/// been silent for 30 days, merged into what iCloud holds so nothing it sent is replaced.
final class StripSendForSilentTests: XCTestCase {
  private let day: Int64 = 86_400_000
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private var nowMs: Int64 { Int64(now.timeIntervalSince1970 * 1000) }

  func testSilentOnlyPastThirtyDays() {
    XCTAssertTrue(StripSync.isSilent(newest: nowMs - 31 * day, now: now))
    XCTAssertFalse(StripSync.isSilent(newest: nowMs - 29 * day, now: now))
    XCTAssertFalse(StripSync.isSilent(newest: nil, now: now), "no rows, nothing to send")
  }

  private func rows(_ data: Data?) -> [StripRow] {
    (data.map(StripSync.decode) ?? []).sorted { ($0.day, $0.item.rawValue) < ($1.day, $1.item.rawValue) }
  }

  private let cloudOct = StripSync.encode([
    StripRow(day: "2026-10-17", item: .balloons, value: 2, updatedAt: 10),
    StripRow(day: "2026-10-18", item: .gym, value: 1, updatedAt: 11),
  ])["2026-10"]!

  /// Only the changes its key lacks go up, merged into the key's month: the newer change per day and item wins.
  func testOnlyChangesTheKeyLacksGoUpMergedIntoIt() {
    let peer = [
      StripRow(day: "2026-10-17", item: .balloons, value: 2, updatedAt: 10),  // already there
      StripRow(day: "2026-10-18", item: .gym, value: 0, updatedAt: 5),  // older than iCloud's
      StripRow(day: "2026-10-19", item: .magic, value: 1, updatedAt: 20),  // never sent
    ]
    let out = StripSync.unsentMonths(peer, oldest: "2026-01") { $0 == "2026-10" ? self.cloudOct : nil }
    XCTAssertEqual(Array(out.keys), ["2026-10"])
    XCTAssertEqual(out["2026-10"]?.rows, 1)
    XCTAssertEqual(
      rows(out["2026-10"]?.data),
      [
        StripRow(day: "2026-10-17", item: .balloons, value: 2, updatedAt: 10),
        StripRow(day: "2026-10-18", item: .gym, value: 1, updatedAt: 11),
        StripRow(day: "2026-10-19", item: .magic, value: 1, updatedAt: 20),
      ])
  }

  /// A newer change in the restore replaces the key's older one for that day and item.
  func testANewerRestoredChangeWins() {
    let peer = [StripRow(day: "2026-10-17", item: .balloons, value: 3, updatedAt: 15)]
    let out = StripSync.unsentMonths(peer, oldest: "2026-01") { _ in self.cloudOct }
    XCTAssertEqual(
      rows(out["2026-10"]?.data).first, StripRow(day: "2026-10-17", item: .balloons, value: 3, updatedAt: 15))
  }

  /// Nothing unsent rewrites nothing; a month iCloud has no key for goes up whole; months it no longer carries don't.
  func testNothingUnsentNoKeyAndAgedOutMonths() {
    let sent = [StripRow(day: "2026-10-17", item: .balloons, value: 2, updatedAt: 10)]
    XCTAssertEqual(StripSync.unsentMonths(sent, oldest: "2026-01") { _ in self.cloudOct }.count, 0)
    let fresh = [StripRow(day: "2026-11-02", item: .journal, value: 1, updatedAt: 30)]
    XCTAssertEqual(StripSync.unsentMonths(fresh, oldest: "2026-01") { _ in nil }["2026-11"]?.rows, 1)
    let old = [StripRow(day: "2025-01-02", item: .journal, value: 1, updatedAt: 30)]
    XCTAssertEqual(StripSync.unsentMonths(old, oldest: "2026-01") { _ in nil }.count, 0)
  }

  /// A later build's items in the old phone's month stay.
  func testUnknownItemsInItsMonthStay() throws {
    let cloud = Data(#"{"2026-10-17":{"unicorns":[1,5]}}"#.utf8)
    let peer = [StripRow(day: "2026-10-17", item: .balloons, value: 1, updatedAt: 9)]
    let data = try XCTUnwrap(StripSync.unsentMonths(peer, oldest: "2026-01") { _ in cloud }["2026-10"]?.data)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: [String: [Int]]])
    XCTAssertEqual(json, ["2026-10-17": ["balloons": [1, 9], "unicorns": [1, 5]]])
  }

  /// The peer rows filed under one device, for the app to judge its silence and what it never sent.
  func testPeerRowsByDevice() throws {
    let strip = try DailyStrip(db: try SQLiteDatabase(path: ":memory:"))
    try strip.mergePeer(
      "old", month: "2026-10", rows: [StripRow(day: "2026-10-17", item: .gym, value: 1, updatedAt: 3)])
    try strip.mergePeer(
      "ipad", month: "2026-10", rows: [StripRow(day: "2026-10-17", item: .gym, value: 1, updatedAt: 4)])
    XCTAssertEqual(try strip.peerRows("old"), [StripRow(day: "2026-10-17", item: .gym, value: 1, updatedAt: 3)])
  }
}
