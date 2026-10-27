//  Two connections to one file, as the app holds them (the main actor's stores and the health cache a grab writes
//  from its task group), and the grab's cache failures kept apart from Health's.

import XCTest

@testable import ContextCore

/// Health with nothing in it: every question answers, none fails.
private struct EmptyHealth: HealthSource {
  func sum(_ kind: QuantityKind, from: Double, to: Double) async throws -> Double? { nil }
  func latest(_ kind: QuantityKind) async throws -> Double? { nil }
  func samples(_ kind: QuantityKind, from: Double, to: Double) async throws -> [QuantitySampleRecord] { [] }
  func sleep(from: Double, to: Double) async throws -> [SleepSample] { [] }
  func mindful(from: Double, to: Double) async throws -> [TimeSpan] { [] }
  func workouts(from: Double, to: Double) async throws -> [WorkoutRecord] { [] }
}

final class SQLiteConnectionTests: XCTestCase {
  private var dir: URL!

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("sqlite-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: dir)
  }

  private var path: String { dir.appendingPathComponent("context-grabber.db").path }

  func testAFileOpensInWALWithABusyTimeout() throws {
    let db = try SQLiteDatabase(path: path)
    XCTAssertEqual(try db.run("PRAGMA journal_mode").first?["journal_mode"]?.textValue, "wal")
    XCTAssertEqual(
      try db.run("PRAGMA busy_timeout").first?["timeout"]?.intValue, Int64(SQLiteDatabase.busyTimeoutMs))
    // Memory has no file to share, so it keeps SQLite's defaults.
    XCTAssertEqual(try SQLiteDatabase().run("PRAGMA journal_mode").first?["journal_mode"]?.textValue, "memory")
  }

  /// M-1: a cache write that lands while the other connection holds the write lock waits for it, instead of
  /// failing at once with SQLITE_BUSY (which the grab then reported as Health not answering).
  func testASecondConnectionWaitsForTheFirstsWrite() throws {
    let main = try SQLiteDatabase(path: path)
    let store = try LocationStore(db: main)
    let cache = try HealthCache(db: SQLiteDatabase(path: path))

    try main.execute("BEGIN IMMEDIATE")
    try main.run(
      "INSERT INTO locations (latitude, longitude, accuracy, timestamp) VALUES (47.6, -122.3, 5, 1780000000000)")
    let committed = expectation(description: "the first connection commits")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
      do { try main.execute("COMMIT") } catch { XCTFail("\(error)") }
      committed.fulfill()
    }
    // A reader is never blocked by the open write.
    XCTAssertEqual(try cache.computed(.steps, ["2026-03-14"]).count, 0)
    XCTAssertNoThrow(try cache.putComputed(.steps, "2026-03-14", DailyValue(date: "2026-03-14", value: 1).json))
    wait(for: [committed], timeout: 5)

    XCTAssertEqual(try store.count(), 1)
    XCTAssertEqual(try cache.computed(.steps, ["2026-03-14"]).count, 1)
  }

  /// A trail batch that lands during a grab's cache writes is kept.
  func testATrailBatchWaitsForTheCachesWrite() throws {
    let store = try LocationStore(db: SQLiteDatabase(path: path))
    let cacheDb = try SQLiteDatabase(path: path)
    _ = try HealthCache(db: cacheDb)

    try cacheDb.execute("BEGIN IMMEDIATE")
    try cacheDb.run("DELETE FROM health_computed_cache WHERE metric = 'steps'")
    let committed = expectation(description: "the cache commits")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
      do { try cacheDb.execute("COMMIT") } catch { XCTFail("\(error)") }
      committed.fulfill()
    }
    XCTAssertNoThrow(
      try store.insert([LocationPoint(latitude: 47.6, longitude: -122.3, accuracy: 5, timestamp: 1_780_000_000_000)]))
    wait(for: [committed], timeout: 5)
    XCTAssertEqual(try store.count(), 1)
  }

  /// The cache failing is the phone's problem, not Health's: it never reaches `takeFailures()`.
  func testACacheFailureIsNotAHealthFailure() async throws {
    let db = try SQLiteDatabase()
    let cache = try HealthCache(db: db)
    try db.execute("DROP TABLE health_computed_cache; DROP TABLE health_raw_cache;")
    let grab = MirrorGrab(source: EmptyHealth(), cache: cache, clock: la)
    _ = await grab.weekly(now: la.localTime(year: 2026, month: 3, day: 15, hour: 12))

    XCTAssertEqual(grab.takeFailures(), [])
    let cacheFailures = grab.takeCacheFailures()
    XCTAssertFalse(cacheFailures.isEmpty)
    XCTAssertEqual(Set(cacheFailures.map(\.query)), ["cache_read", "cache_write"])
    XCTAssertEqual(grab.takeCacheFailures(), [], "taken once")
  }
}
