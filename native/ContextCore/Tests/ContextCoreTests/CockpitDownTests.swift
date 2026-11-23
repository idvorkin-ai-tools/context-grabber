import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Stories 1604–1606 (bead context-grabber-3kgu): what counts as the Cockpit down, when the banner shows and goes, and
/// what its copyable words say.
final class CockpitDownTests: XCTestCase {
  private let utc = TimeZone(identifier: "UTC")!
  /// 2026-11-29 12:31 and 12:39 UTC, in ms.
  private let at1231: Int64 = 1_795_955_460_000
  private let at1239: Int64 = 1_795_955_940_000

  func testWhatCountsAsDown() {
    for status in [500, 502, 503, 504, 599] { XCTAssertTrue(CockpitDown.isDown(status: status), "\(status)") }
    for status in [200, 400, 404, 429, 600] { XCTAssertFalse(CockpitDown.isDown(status: status), "\(status)") }
    XCTAssertTrue(CockpitDown.isDown(URLError(.timedOut)))
    XCTAssertTrue(CockpitDown.isDown(URLError(.cannotConnectToHost)))
    XCTAssertTrue(CockpitDown.isDown(URLError(.cannotFindHost)))
    XCTAssertTrue(CockpitDown.isDown(URLError(.networkConnectionLost)))
    XCTAssertFalse(CockpitDown.isDown(URLError(.notConnectedToInternet)), "the device offline has its own line")
    XCTAssertFalse(CockpitDown.isDown(URLError(.badURL)))
    XCTAssertFalse(CockpitDown.isDown(CocoaError(.fileNoSuchFile)))
  }

  /// Story 1604: an empty screen says so at the first failure; an empty list must never pass for no chats.
  func testNothingLoadedShowsAtOnce() {
    var down = CockpitDown()
    XCTAssertTrue(down.failed("answered HTTP 502", loaded: false, now: at1239))
  }

  /// Story 1606: a loaded screen shows nothing for one blip, and the banner at the second failure in a row.
  func testLoadedShowsAtTheSecondFailure() {
    var down = CockpitDown()
    down.answered(now: at1231)
    XCTAssertFalse(down.failed("answered HTTP 502", loaded: true, now: at1239))
    XCTAssertTrue(down.failed("answered HTTP 502", loaded: true, now: at1239 + 4_000))
    XCTAssertTrue(down.failed("answered HTTP 502", loaded: true, now: at1239 + 8_000), "it stays while it lasts")
  }

  /// Story 1606: a blip healed by the next read leaves no count behind; the banner goes at the first read through.
  func testAReadThatGetsThroughClears() {
    var down = CockpitDown()
    XCTAssertFalse(down.failed("answered HTTP 502", loaded: true, now: at1231))
    down.answered(now: at1231 + 4_000)
    XCTAssertFalse(down.showing)
    XCTAssertFalse(down.failed("answered HTTP 502", loaded: true, now: at1239), "the count started again")
    XCTAssertTrue(down.failed("answered HTTP 502", loaded: true, now: at1239 + 4_000))
    down.answered(now: at1239 + 8_000)
    XCTAssertFalse(down.showing)
    XCTAssertNil(down.since)
    XCTAssertEqual(down.lastGood, at1239 + 8_000)
  }

  /// Story 1605: what failed, how, since when, the last good read; the words stay the same through the outage.
  func testTheProblemSaysWhatSinceWhenAndTheLastGoodRead() {
    var down = CockpitDown()
    down.answered(now: at1231)
    _ = down.failed(CockpitDown.how(status: 502), loaded: true, now: at1239)
    let first = down.problem(what: "reading this chat", timeZone: utc)
    XCTAssertEqual(
      first,
      "Cockpit not answering — reading this chat answered HTTP 502 since 12:39; last good read 12:31. "
        + "Your messages are kept and go when it answers.")
    _ = down.failed(CockpitDown.how(status: 504), loaded: true, now: at1239 + 4_000)
    XCTAssertEqual(down.problem(what: "reading this chat", timeZone: utc), first, "a later poll changes nothing")
  }

  func testNoGoodReadAndAReason() {
    var down = CockpitDown()
    _ = down.failed(CockpitDown.how(URLError(.timedOut)), loaded: false, now: at1239)
    let problem = down.problem(what: "reading the chats", timeZone: utc)
    XCTAssertTrue(problem.hasPrefix("Cockpit not answering — reading the chats failed ("), problem)
    XCTAssertTrue(problem.contains(") since 12:39; no good read since the app opened."), problem)
  }

  /// A last good read on another day names its date.
  func testALastGoodReadOnAnotherDayNamesTheDate() {
    var down = CockpitDown()
    down.answered(now: at1231 - 86_400_000)
    _ = down.failed(CockpitDown.how(status: 502), loaded: true, now: at1239)
    XCTAssertTrue(
      down.problem(what: "reading the chats", timeZone: utc).contains("last good read 2026-11-28 12:31."))
  }
}
