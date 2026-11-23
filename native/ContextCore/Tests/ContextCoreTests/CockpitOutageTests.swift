import XCTest

@testable import ContextCore

final class CockpitOutageTests: XCTestCase {
  func testKinds() {
    XCTAssertEqual(CockpitOutage.kind(status: 502), .away)
    XCTAssertEqual(CockpitOutage.kind(status: 503), .away)
    XCTAssertEqual(CockpitOutage.kind(status: 504), .away)
    XCTAssertEqual(CockpitOutage.kind(status: 404), .other)
    XCTAssertEqual(CockpitOutage.kind(status: 500), .other)
    XCTAssertEqual(CockpitOutage.kind(status: 200), .other, "a 200 the app could not read is a bug")
    XCTAssertEqual(CockpitOutage.kind(URLError(.timedOut)), .away)
    XCTAssertEqual(CockpitOutage.kind(URLError(.cannotConnectToHost)), .away)
    XCTAssertEqual(CockpitOutage.kind(URLError(.notConnectedToInternet)), .deviceOffline)
    XCTAssertEqual(CockpitOutage.kind(URLError(.networkConnectionLost)), .away, "a proxy dropping its connection")
    XCTAssertEqual(CockpitOutage.kind(URLError(.badURL)), .other)
    XCTAssertEqual(CockpitOutage.kind(CocoaError(.fileNoSuchFile)), .other)
  }

  /// #1245–#1253: one poll in a hundred answered 502 and the next read fine; each blip filed a report.
  func testABlipThatHealsFilesNothing() {
    var outage = CockpitOutage()
    XCTAssertEqual(outage.failed(.away, now: 1_000), .quiet)
    XCTAssertEqual(outage.succeeded(now: 5_000), .init(ms: 4_000, failures: 1, filed: false))
    XCTAssertNil(outage.started)
  }

  func testTwoMinutesOfFailuresFilesOnce() {
    var outage = CockpitOutage()
    var verdicts: [CockpitOutage.Verdict] = []
    for poll in 0...60 { verdicts.append(outage.failed(.away, now: Int64(poll) * 4_000)) }
    let filed = verdicts.filter { if case .fileOutage = $0 { return true } else { return false } }
    XCTAssertEqual(filed, [.fileOutage(ms: 120_000, failures: 31)])
    XCTAssertEqual(outage.succeeded(now: 250_000), .init(ms: 250_000, failures: 61, filed: true))
  }

  func testASuccessStartsTheCountAgain() {
    var outage = CockpitOutage()
    _ = outage.failed(.away, now: 0)
    _ = outage.failed(.away, now: 100_000)
    _ = outage.succeeded(now: 104_000)
    XCTAssertEqual(outage.failed(.away, now: 108_000), .quiet)
    XCTAssertEqual(outage.failed(.away, now: 200_000), .quiet, "only 92 s since this outage began")
  }

  /// Polling stops when the thread closes: two failures an hour apart are not one outage.
  func testAPauseWithNoReadStartsTheCountAgain() {
    var outage = CockpitOutage()
    _ = outage.failed(.away, now: 0)
    XCTAssertEqual(outage.failed(.away, now: 3_600_000), .quiet)
    XCTAssertEqual(outage.started, 3_600_000)
    XCTAssertEqual(outage.failures, 1)
  }

  func testOtherFailuresFileAtOnceAndLeaveTheOutageAlone() {
    var outage = CockpitOutage()
    _ = outage.failed(.away, now: 0)
    XCTAssertEqual(outage.failed(.other, now: 4_000), .file)
    XCTAssertEqual(outage.failures, 1)
  }

  /// #1268: the iPad woke before the app noticed it was offline.
  func testTheDeviceOfflineNeverFiles() {
    var outage = CockpitOutage()
    for poll in 0...100 { XCTAssertEqual(outage.failed(.deviceOffline, now: Int64(poll) * 4_000), .quiet) }
    XCTAssertNil(outage.succeeded(now: 500_000))
  }
}
