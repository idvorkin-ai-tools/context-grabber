import Foundation
import XCTest

@testable import ContextCore

/// Stories 1237–1239, 1248 (bead context-grabber-8ao5.2): the iPad's recorder takes the board's own log events as they
/// are written and cuts sessions at five idle minutes. Fed the board events of the two pulled iPad logs (only the
/// fields it reads, `*.events` beside the review fixtures), it makes the same records the converter made from those
/// logs, so the iPad reviews them to the manual review's verdict.
final class BoardReviewRecorderTests: XCTestCase {
  static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
    "Fixtures/board-reviews")

  /// Every session the recorder closes in a log's events, in order: a session closes when an event comes five idle
  /// minutes after a step of Igor's, and the last at the end.
  private func sessions(_ name: String, board: String) throws -> [BoardSessionRecord] {
    let text = try String(contentsOf: Self.folder.appendingPathComponent("\(name).events"), encoding: .utf8)
    var recorder = BoardReviewRecorder(board: board)
    var out: [BoardSessionRecord] = []
    for line in text.split(separator: "\n") {
      let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
      let t = try XCTUnwrap(fields["t"] as? Double ?? (fields["t"] as? Int).map(Double.init))
      if recorder.due(now: t), let record = recorder.record {
        out.append(record)
        recorder.nextSession()
      }
      recorder.take(type: fields["type"] as? String ?? "", t: t, fields: fields)
    }
    if recorder.hasIgorsStep, let record = recorder.record { out.append(record) }
    return out
  }

  private func fixture(_ name: String) throws -> BoardSessionRecord {
    try BoardSessionRecord(jsonl: Data(contentsOf: Self.folder.appendingPathComponent("\(name).jsonl")))
  }

  /// Steps as compared: the converter leaves owners off some changes the recorder names.
  private func plain(_ steps: [BoardSessionRecord.Step]) -> [BoardSessionRecord.Step] {
    steps.map { step in
      var step = step
      step.changes = step.changes?.map { change in
        var change = change
        change.owner = nil
        return change
      }
      return step
    }
  }

  func testTheIPadsAfternoonIsThreeSessionsAndTheLastTwoAreTheConvertersRecords() throws {
    let got = try sessions("ipad-2026-11-23-6bae", board: "6bae4457-dfda-46a8-bd83-0a4b54df5d13")
    XCTAssertEqual(got.count, 3)
    for (record, name) in zip(got.dropFirst(), ["ipad-2026-11-23-6bae-a", "ipad-2026-11-23-6bae-b"]) {
      let want = try fixture(name)
      XCTAssertEqual(record.header.ink, want.header.ink, name)
      XCTAssertEqual(plain(record.steps), plain(want.steps), name)
      XCTAssertEqual(
        BoardReview.run(record).findings.map { "\($0.check) \($0.verdict.rawValue)" },
        BoardReview.run(want).findings.map { "\($0.check) \($0.verdict.rawValue)" }, name)
    }
  }

  func testTheEveningIsOneSessionReviewedClean() throws {
    let got = try sessions("ipad-2026-11-22-4d71", board: "4d711296-1357-41c5-8e84-2ba3c23cbe7a")
    XCTAssertEqual(got.count, 1)
    let record = try XCTUnwrap(got.first)
    XCTAssertEqual(record.header.ink, try fixture("ipad-2026-11-22-4d71").header.ink)
    XCTAssertEqual(BoardReview.run(record).findings, [])
  }

  func testOnlyLookingIsNotDueAndIdleIsFiveMinutesAfterHisStep() {
    var recorder = BoardReviewRecorder(board: "b")
    recorder.take(
      type: "whiteboard", t: 0, fields: ["action": "paper_open", "board": "b", "strokes": 0, "ink": [0, 0, 0, 0]])
    recorder.take(type: "whiteboard", t: 100, fields: ["action": "paper_selection", "board": "b", "box": [Int]()])
    XCTAssertFalse(recorder.hasIgorsStep)
    XCTAssertFalse(recorder.due(now: 1_000_000))
    recorder.take(
      type: "whiteboard", t: 1000,
      fields: [
        "action": "paper_ink", "board": "b", "added": 1, "moved": 0, "removed": 0, "added_box": [1, 2, 3, 4],
        "strokes": 1,
      ])
    recorder.take(type: "whiteboard", t: 2000, fields: ["action": "paper_ink", "board": "other", "added": 1])
    XCTAssertTrue(recorder.hasIgorsStep)
    XCTAssertFalse(recorder.due(now: 1000 + BoardReviewRecorder.idle - 1))
    XCTAssertTrue(recorder.due(now: 1000 + BoardReviewRecorder.idle))
    XCTAssertEqual(recorder.record?.steps.count, 2)
    recorder.nextSession()
    XCTAssertNil(recorder.record)
  }

  private func shown(_ name: String, asked: Bool = false) throws -> BoardReviewShown {
    let record = try fixture(name)
    var shown = BoardReviewShown()
    shown.show(BoardReview.run(record), of: record, asked: asked)
    return shown
  }

  func testTheNoteSaysWhatToLookAtAndGoesWhenOpened() throws {
    XCTAssertNil(try shown("check2-clean").note, "story 1242: a clean review shows nothing")
    XCTAssertEqual(try shown("check2-clean", asked: true).note, "Reviewed · clean")
    XCTAssertNil(try shown("check7-put-back").note, "as designed doesn't count")
    var note = try shown("check3-knob-stretch")
    XCTAssertEqual(note.note, "Reviewed · 1 to look at")
    note.noteDone()
    XCTAssertNil(note.note)
  }

  func testAnAnswerLeavesTheNoteAndGoesToLarryOnce() throws {
    var shown = try shown("check3-knob-stretch")
    let finding = try XCTUnwrap(shown.findings.first)
    let first = try XCTUnwrap(shown.forLarry())
    XCTAssertTrue(first.contains("check 3 moved_without_aim: 0 bug, 1 unclear"), first)
    XCTAssertNil(shown.forLarry(), "once")
    shown.answer(finding, .meant)
    XCTAssertNil(shown.note)
    XCTAssertTrue(try XCTUnwrap(shown.forLarry()).hasSuffix("Igor on step 0 (check 3): I meant that"))
  }

  func testShowMeHasErasedInkInTheBeforeAndTheMoveInTheAfter() throws {
    let record = try fixture("check6-fires")
    let boards = BoardReview.around(record, step: 0)
    XCTAssertEqual(boards.before.first { $0.id == "a" }?.box.y, 100)
    XCTAssertEqual(boards.after.first { $0.id == "a" }?.box.y, 180)
    let erase = BoardSessionRecord(
      header: record.header,
      steps: [.init(t: 1, kind: "erase", by: "pencil", changes: [.init(id: "a", before: .init(60, 100, 300, 30))])])
    let erased = BoardReview.around(erase, step: 0)
    XCTAssertNotNil(erased.before.first { $0.id == "a" }, "story 1245: erased ink as it was")
    XCTAssertNil(erased.after.first { $0.id == "a" })
  }

  func testARecordKeptOnTheDeviceReadsBackAsItWas() throws {
    for name in ["ipad-2026-11-23-6bae-a", "check5-eysh", "check9-healed"] {
      let record = try fixture(name)
      XCTAssertEqual(try BoardSessionRecord(jsonl: record.jsonl()), record, name)
    }
  }
}
