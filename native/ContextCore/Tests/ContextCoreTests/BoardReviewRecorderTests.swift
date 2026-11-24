import Foundation
import XCTest

@testable import ContextCore

/// Stories 1237–1239, 1248 (bead context-grabber-8ao5.3): the iPad's recorder takes the board's real strokes at each
/// step, as the board hands them over, and the board's log events only for what kind of step it was, who started it and
/// what it was aimed at. Each case is a board as the iPad would hand it over, step by step, and its review.
final class BoardReviewRecorderTests: XCTestCase {
  typealias Ink = BoardReviewRecorder.InkNow
  typealias Box = BoardSessionRecord.Box
  static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
    "Fixtures/board-reviews")

  private func ink(_ boxes: [String: (String, Box)], hidden: Set<String> = []) -> [String: Ink] {
    boxes.mapValues { Ink(owner: $0.0, box: $0.1) }.reduce(into: [:]) { out, pair in
      var value = pair.value
      value.hidden = hidden.contains(pair.key)
      out[pair.key] = value
    }
  }

  private struct Board {
    var recorder = BoardReviewRecorder(board: "b")
    var t = 1000.0

    mutating func event(
      _ action: String, _ fields: [String: Any] = [:], ink: [String: Ink]? = nil,
      folds: [BoardReviewRecorder.FoldNow]? = nil, after: Double = 100
    ) {
      t += after
      var all = fields
      all["action"] = action
      all["board"] = "b"
      recorder.take(type: "whiteboard", t: t, fields: all, ink: ink, folds: folds)
    }

    var review: BoardReview.Report? { recorder.record.map(BoardReview.run) }
    var found: [String] { (review?.findings ?? []).map { "\($0.check) \($0.verdict.rawValue)" }.sorted() }
    var kinds: [String] { recorder.steps.map(\.kind) }
  }

  let a = Box(60, 100, 300, 30)
  let b = Box(60, 140, 300, 30)

  func testABoardThatOpensWithInkStartsFromItsStrokesAndAKeepAmongThemThatOpensRoomIsClean() {
    var board = Board()
    let opened = ink(["a": ("igor", a), "b": ("igor", b)])
    board.event("paper_open", ink: opened)
    // Larry's text kept where b was, b pushed down a line: the keep, then its room, a moment later.
    let kept = ink(["a": ("igor", a), "b": ("igor", b), "k": ("larry", Box(60, 140, 200, 20))])
    board.event("paper_keep", ["tool_before": "pen", "tool_after": "pen"], ink: kept)
    let pushed = ink(["a": ("igor", a), "b": ("igor", Box(60, 180, 300, 30)), "k": ("larry", Box(60, 140, 200, 20))])
    board.event("keep_text", ["cut": 135, "dy": 40], ink: pushed)
    XCTAssertEqual(board.recorder.record?.header.ink.map(\.id), ["a", "b"], "the board as it opened, stroke by stroke")
    XCTAssertEqual(board.kinds, ["keep"], "the room joins its keep")
    XCTAssertEqual(board.recorder.steps.first?.room, .init(cut: 135, dy: 40))
    XCTAssertEqual(board.found, [])
  }

  func testAKeepThatLandsOnOldWritingWithNoRoomIsABug() {
    var board = Board()
    board.event("paper_open", ink: ink(["a": ("igor", a), "b": ("igor", b)]))
    board.event(
      "paper_keep", ["tool_before": "pen", "tool_after": "pen"],
      ink: ink(["a": ("igor", a), "b": ("igor", b), "k": ("larry", Box(60, 140, 200, 20))]))
    XCTAssertEqual(board.found, ["2 bug"])
  }

  func testAnEraseThenItsUndoAndRedoAreCleanAndAnUndoThatLeftAStrokeMovedIsABug() {
    var board = Board()
    let both = ink(["a": ("igor", a), "b": ("igor", b)])
    board.event("paper_open", ink: both)
    board.event("paper_ink", ["in_touch": true], ink: ink(["a": ("igor", a)]))
    board.event("paper_ink", ["in_touch": false, "undoing": true], ink: both, folds: [])
    board.event("paper_ink", ["in_touch": false, "undoing": true, "redoing": true], ink: ink(["a": ("igor", a)]))
    XCTAssertEqual(board.kinds, ["erase", "undo", "redo"])
    XCTAssertEqual(board.found, [])

    var wrong = Board()
    wrong.event("paper_open", ink: both)
    wrong.event("paper_ink", ["in_touch": true], ink: ink(["a": ("igor", a)]))
    wrong.event(
      "paper_ink", ["in_touch": false, "undoing": true],
      ink: ink(["a": ("igor", a), "b": ("igor", Box(60, 300, 300, 30))]))
    XCTAssertEqual(wrong.found, ["6 bug"])
  }

  func testAFoldHidesItsSectionAndRefoldingSwallowingNewInkIsABug() {
    var board = Board()
    let h = Box(60, 100, 200, 30)
    let s = Box(80, 140, 300, 30)
    board.event(
      "paper_open", ink: ink(["h": ("igor", h), "s": ("igor", s)]), folds: [.init(header: "h", held: [], folded: false)]
    )
    board.event(
      "changed", ["label": "Fold"], ink: ink(["h": ("igor", h), "s": ("igor", s)], hidden: ["s"]),
      folds: [.init(header: "h", held: ["s"], folded: true)])
    XCTAssertEqual(board.kinds, ["fold"])
    // Written under the folded header, unfolded, folded again: the fold takes the new line too (bead eysh).
    board.event(
      "paper_ink", ["in_touch": true],
      ink: ink(["h": ("igor", h), "s": ("igor", s), "n": ("igor", Box(60, 140, 100, 20))], hidden: ["s"]))
    board.event(
      "changed", ["label": "Unfold"],
      ink: ink(["h": ("igor", h), "s": ("igor", Box(80, 180, 300, 30)), "n": ("igor", Box(60, 140, 100, 20))]),
      folds: [.init(header: "h", held: ["s"], folded: false)])
    board.event(
      "changed", ["label": "Fold"],
      ink: ink(["h": ("igor", h), "s": ("igor", s), "n": ("igor", Box(60, 140, 100, 20))], hidden: ["s", "n"]),
      folds: [.init(header: "h", held: ["s", "n"], folded: true)])
    XCTAssertEqual(board.kinds, ["fold", "ink", "unfold", "fold"])
    XCTAssertEqual(board.found, ["5 bug"])
  }

  func testAPasteAndItsRoomAreOneStepAndClean() {
    var board = Board()
    board.event("paper_open", ink: ink(["a": ("igor", a)]))
    // The paste's strokes come in through PaperKit, with no touch, then the paste is logged.
    board.event("paper_ink", ["in_touch": false], ink: ink(["a": ("igor", a), "p": ("igor", Box(60, 200, 100, 20))]))
    board.event("paste", ink: ink(["a": ("igor", a), "p": ("igor", Box(60, 200, 100, 20))]))
    XCTAssertEqual(board.kinds, ["paste"])
    XCTAssertEqual(board.found, [])
  }

  func testLarrysOpsMovingIgorsInkAreHisAimNotABug() {
    var board = Board()
    board.event("paper_open", ink: ink(["a": ("igor", a), "l": ("larry", Box(400, 100, 100, 30))]))
    board.event("applied", ink: ink(["a": ("igor", Box(60, 300, 300, 30)), "l": ("larry", Box(400, 100, 100, 30))]))
    XCTAssertEqual(board.kinds, ["ops"])
    XCTAssertEqual(board.recorder.steps.first?.by, "larry")
    XCTAssertEqual(board.found, [])
  }

  func testADropOnALineJoinsItsRoomAndIsClean() {
    var board = Board()
    let g = Box(60, 300, 200, 40)
    board.event("paper_open", ink: ink(["g": ("larry", g), "a": ("igor", a)]))
    board.event(
      "paper_selection", ["box": [60, 300, 200, 40], "selected": 1], ink: ink(["g": ("larry", g), "a": ("igor", a)]))
    board.event(
      "paper_ink", ["in_touch": true, "selected": 1, "start_view": "CanvasElementResizeView"],
      ink: ink(["g": ("larry", Box(60, 95, 200, 40)), "a": ("igor", a)]))
    board.event(
      "paper_drop", ["room": true, "cut": 95, "dy": 80],
      ink: ink(["g": ("larry", Box(60, 95, 200, 40)), "a": ("igor", Box(60, 180, 300, 30))]))
    XCTAssertEqual(board.kinds, ["select", "drop"])
    XCTAssertEqual(board.recorder.steps.last?.aim?.ids, ["g"])
    XCTAssertEqual(board.found, [])
  }

  func testAReflowPutApartIsAsDesigned() {
    var board = Board()
    let l = Box(60, 100, 300, 50)
    let m = Box(60, 160, 100, 20)
    board.event("paper_open", ink: ink(["l": ("larry", l), "m": ("igor", m)]))
    board.event(
      "paper_ink", ["in_touch": true, "selected": 0, "start_view": "CanvasElementResizeHandle"],
      ink: ink(["l": ("larry", Box(80, 120, 300, 50)), "m": ("igor", Box(80, 180, 100, 20))]))
    board.event("paper_apart", ["whose": "mine"], ink: ink(["l": ("larry", Box(80, 120, 300, 50)), "m": ("igor", m)]))
    XCTAssertEqual(board.kinds, ["move", "apart"])
    XCTAssertEqual(board.found, ["4 as_designed"])
  }

  func testOnlyLookingIsNotHisStepAndAStrokeIs() {
    var board = Board()
    board.event("paper_open", ink: ink(["a": ("igor", a)]))
    board.event("paper_selection", ["box": [Int]()], ink: ink(["a": ("igor", a)]))
    XCTAssertFalse(board.recorder.hasIgorsStep)
    XCTAssertEqual(board.recorder.record?.hasIgorsStep, false)
    board.event("paper_ink", ["in_touch": true], ink: ink(["a": ("igor", a), "n": ("igor", b)]))
    board.recorder.take(type: "whiteboard", t: 9e9, fields: ["action": "paper_ink", "board": "other"], ink: [:])
    XCTAssertTrue(board.recorder.hasIgorsStep)
    XCTAssertEqual(board.recorder.record?.hasIgorsStep, true)
    board.recorder.nextSession()
    XCTAssertNil(board.recorder.record)
  }

  func testLarrysWordsStayUnderTheCockpitsEightKilobytes() {
    let long = (0..<400).map { "line \($0) of a long review, with its evidence" }.joined(separator: "\n")
    let cut = BoardReviewShown.cut(long, to: BoardReviewShown.larryBytes)
    XCTAssertLessThanOrEqual(cut.utf8.count, BoardReviewShown.larryBytes)
    XCTAssertTrue(cut.hasSuffix("more lines are in the copy on the iPad)"), cut.suffix(120).description)
    XCTAssertEqual(BoardReviewShown.cut("short", to: 7000), "short")
  }

  private func fixture(_ name: String) throws -> BoardSessionRecord {
    try BoardSessionRecord(jsonl: Data(contentsOf: Self.folder.appendingPathComponent("\(name).jsonl")))
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
