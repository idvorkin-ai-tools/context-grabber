import Foundation
import XCTest

@testable import ContextCore

/// Stories 1182, 1183 (bead context-grabber-09tx): the Cockpit's recorded board sessions (board contract v1, cockpit 9ca45fe,
/// scrubbed: `scripts/native/board-sessions.py`) replayed with the board's own rules. Each of Larry's batches gets the
/// answer the iPad really sent, and each of Igor's turns carries what the Cockpit's recorded hint told Larry.
final class BoardSessionReplayTests: XCTestCase {
  static let names = ["ops-move", "plain-draw", "question-card", "title-build"]

  private func url(_ file: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
      "Fixtures/board-sessions/\(file)")
  }

  private func session(_ name: String) throws -> BoardSession {
    try BoardSession(jsonl: Data(contentsOf: url("\(name).jsonl")))
  }

  private func contexts(_ name: String) throws -> [String: String] {
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url("\(name).golden.json"))) as? [String: Any]
    return json?["contexts"] as? [String: String] ?? [:]
  }

  /// Where today's board answers otherwise than the build that was recorded, and why. ops-move was recorded on
  /// 2026-11-16, the night before story 961 let a batch from an older look apply over Igor's new strokes.
  static let changedSince = ["ops-move": ["batch 49946d13484f"]]

  func testEverySessionIsContractOneAndReplaysAsRecordedButForWhatChangedSince() throws {
    for name in Self.names {
      let session = try session(name)
      XCTAssertEqual(session.contract, BoardSession.contractVersion, name)
      XCTAssertEqual(session.name, name)
      let report = session.replay()
      XCTAssertFalse(report.turns.isEmpty, name)
      let known = Self.changedSince[name] ?? []
      XCTAssertEqual(
        report.mismatches.filter { mismatch in !known.contains { mismatch.hasPrefix($0) } }, [], name)
      XCTAssertEqual(report.mismatches.count, known.count, "\(name): \(report.mismatches)")
    }
  }

  func testEachTurnCarriesWhatTheCockpitsRecordedHintToldLarry() throws {
    for name in Self.names {
      let session = try session(name)
      let golden = try contexts(name)
      let turns = session.replay().turns
      XCTAssertEqual(Set(turns.map(\.id)), Set(golden.keys), name)
      for turn in turns {
        guard turn.onBoard else {
          XCTAssertFalse(golden[turn.id]?.contains("· board ") ?? true, "\(name) \(turn.id) is words alone")
          continue
        }
        let hint = turn.hint(board: session.board, thread: session.thread)
        XCTAssertTrue(
          golden[turn.id]?.hasSuffix(" " + hint) == true, "\(name) \(turn.id):\n\(hint)\n\(golden[turn.id] ?? "")")
      }
    }
  }

  func testABatchAfterIgorDrewOnceMoreNowAppliesWhereTheRecordedBuildRefusedIt() throws {
    let batches = try session("ops-move").replay().batches
    XCTAssertEqual(batches.count, 2)
    let first = try XCTUnwrap(batches.first)
    // The iPad of 2026-11-16 refused it as stale at 257: Igor had drawn one more stroke after Larry's look at 256.
    XCTAssertEqual(first.arrivedAt, 257)
    XCTAssertEqual(first.recorded?.ok, false)
    XCTAssertEqual(first.recorded?.reason, "stale")
    // Since story 961 a new stroke never conflicts: the same batch applies, rebased from his look.
    XCTAssertEqual(first.replayed?.ok, true)
    XCTAssertEqual(first.replayed?.rebasedFrom, 256)
    XCTAssertEqual(first.replayed?.rev, 258)
    XCTAssertFalse(first.matches)
    // The resend's answer was never posted (the session ends first): it applies on the board as it then stood.
    XCTAssertNil(batches.last?.recorded)
    XCTAssertEqual(batches.last?.replayed?.ok, true)
  }

  func testAResendIsNotPairedWithTheRefusalTheIPadRepeatsBeforeFetchingIt() throws {
    let data = try Data(contentsOf: url("ops-move.jsonl"))
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    let refusing = try XCTUnwrap(lines.last { $0.contains("\"op_result\"") })
    let again = refusing.replacingOccurrences(
      of: "8aa9b297-181e-4d35-9251-45796cef9ef6", with: "00000000-0000-0000-0000-000000000001")
    let session = try BoardSession(jsonl: Data((lines + [again]).joined(separator: "\n").utf8))
    let resend = try XCTUnwrap(session.replay().batches.last)
    XCTAssertNil(resend.recorded)
    XCTAssertEqual(resend.replayed?.ok, true)
  }

  func testADeleteWhileIgorKeptWritingAppliesRebasedFromHisLook() throws {
    let batch = try XCTUnwrap(session("question-card").replay().batches.first)
    XCTAssertEqual(batch.replayed?.ok, true)
    XCTAssertEqual(batch.replayed?.rebasedFrom, 179)
    XCTAssertEqual(batch.replayed?.rev, 228)
    XCTAssertEqual(batch.recorded?.rev, 228)
    XCTAssertTrue(batch.matches)
  }

  // His labels have letters only where there are fonts: the Mac, not `just test-linux`.
  #if canImport(CoreText)
    func testLarrysMarksShowAndHisWordsOnlyRepliesAreSaid() throws {
      let marks = try session("plain-draw").replay().marks
      XCTAssertEqual(marks.first?.action, "shown")
      XCTAssertEqual(marks.first?.marks.count, 2)
    }
  #endif

  func testAHintQuotesALabelAsTheCockpitDoes() {
    XCTAssertEqual(BoardSession.Turn.quoted("make room"), "'make room'")
    XCTAssertEqual(BoardSession.Turn.quoted("Remove 'not yet'"), "\"Remove 'not yet'\"")
  }

  func testAHeaderlessSessionIsUnreadable() {
    XCTAssertThrowsError(try BoardSession(jsonl: Data("{\"step\": \"post\"}\n".utf8)))
  }
}
