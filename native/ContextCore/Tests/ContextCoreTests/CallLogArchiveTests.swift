//  Stories 212, 214, 215 (#442): a call's log as the Cockpit archive's records.

import XCTest

@testable import ContextCore

final class CallLogArchiveTests: XCTestCase {
  private func aCall(session: Any? = "15b48d132e64") -> CallEventLog {
    let log = CallEventLog()
    log.add("call_start", t: 1000, fields: ["backend": "direct", "voice": "tony"])
    var ready: [String: Any] = ["out_rate": 24000.0]
    if let session { ready["session"] = session }
    log.add("call_ready", t: 2500, fields: ready)
    log.add("call_ended", t: 9000, fields: ["reason": "stopped", "badly": false])
    return log
  }

  /// The archive's contract (archive.py): a guid per record, 1–128 of `[A-Za-z0-9_.:+-]`, unique per stream.
  private let guidShape = try! NSRegularExpression(pattern: "^[A-Za-z0-9][A-Za-z0-9_.:+-]{0,127}$")

  private func guids(_ records: [[String: Any]]) -> [String] { records.compactMap { $0["guid"] as? String } }

  func testEachLineIsARecordUnderTheBridgeSessionInOrderAfterAHeader() {
    let log = aCall()
    let records = CallLogArchive.records(
      header: [("build", "abc (main)"), ("problem", ""), ("session log", "grabber-1.jsonl")], events: log.currentCall)
    XCTAssertEqual(records.count, 4)
    XCTAssertEqual(
      guids(records), ["15b48d132e64:00000", "15b48d132e64:00001", "15b48d132e64:00002", "15b48d132e64:00003"])
    XCTAssertEqual(records[0]["kind"] as? String, "header")
    XCTAssertEqual(records[0]["call"] as? String, "15b48d132e64")
    XCTAssertEqual(records[0]["build"] as? String, "abc (main)")
    XCTAssertEqual(records[0]["session_log"] as? String, "grabber-1.jsonl")
    XCTAssertNil(records[0]["problem"])  // empty header values are left out
    XCTAssertEqual(records[0]["events"] as? Int, 3)
    XCTAssertEqual(records[1]["seq"] as? Int, 1)
    XCTAssertEqual(records[1]["t"] as? Int, 1000)
    XCTAssertEqual(records[1]["line"] as? String, "+1.0s call_start backend=direct voice=tony")
    XCTAssertEqual(records[3]["seq"] as? Int, 3)
    XCTAssertEqual(records[3]["line"] as? String, "+9.0s call_ended badly=false reason=stopped")
    for guid in guids(records) {
      XCTAssertEqual(guidShape.numberOfMatches(in: guid, range: NSRange(location: 0, length: guid.utf16.count)), 1)
    }
  }

  func testACallThatNeverHeardReadyTakesAFreshLocalKey() {
    let log = CallEventLog()
    log.add("call_start", t: 1000, fields: ["backend": "eleven"])
    log.add("call_ended", t: 4000, fields: ["reason": "connection lost", "badly": true])
    XCTAssertEqual(CallLogArchive.key(log.currentCall, fallback: "local-abc"), "local-abc")
    XCTAssertEqual(
      guids(CallLogArchive.records(header: [], events: log.currentCall, fallback: "local-abc")).first,
      "local-abc:00000")
    // Codex on #443: t counts from launch, so two such calls must not share a key, or the archive drops the second.
    let first = CallLogArchive.key(log.currentCall)
    let second = CallLogArchive.key(log.currentCall)
    XCTAssertTrue(first.hasPrefix("local-"))
    XCTAssertNotEqual(first, second)
  }

  func testASessionTheArchiveWouldRefuseFallsBackToTheLocalKey() {
    for session: Any in ["s 1/x", ":abc", "", 42] {
      XCTAssertEqual(CallLogArchive.key(aCall(session: session).currentCall, fallback: "local-x"), "local-x")
    }
    XCTAssertEqual(CallLogArchive.key(aCall(session: "ok-session.1").currentCall), "ok-session.1")
  }

  func testALongLineIsCutUntilItsRecordFitsTheArchivesBytes() throws {
    // Codex on #443: escaped quotes and non-ASCII take more bytes than characters.
    for text in [String(repeating: "x", count: 9000), String(repeating: "é\"🙂", count: 3000)] {
      let log = CallEventLog()
      log.add("call_start", t: 0, fields: [:])
      log.add("call_caption", t: 10, fields: ["who": "larry", "text": text])
      let records = CallLogArchive.records(header: [], events: log.currentCall)
      let bytes = try JSONSerialization.data(withJSONObject: records[2]).count
      XCTAssertLessThanOrEqual(bytes, CallLogArchive.maxRecordBytes)
      XCTAssertGreaterThan(bytes, CallLogArchive.maxRecordBytes - 16, "cut no shorter than it must be")
    }
    let log = CallEventLog()
    log.add("call_start", t: 0, fields: [:])
    log.add("call_caption", t: 10, fields: ["who": "larry", "text": "short"])
    XCTAssertTrue(
      (CallLogArchive.records(header: [], events: log.currentCall)[2]["line"] as? String)!.contains("short"))
  }
}
