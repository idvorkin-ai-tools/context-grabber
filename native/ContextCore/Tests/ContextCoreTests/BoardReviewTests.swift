import Foundation
import XCTest

@testable import ContextCore

/// Stories 1241, 1250–1262 (spec 2026-11-23-board-interaction-review-design.md, bead context-grabber-8ao5.1): every
/// recorded session under Fixtures/board-reviews reviews to the findings its check expects and to its golden report,
/// which `scripts/native/test-board-wasm.mjs` holds the wasm build to as well. `BOARD_REVIEW_GOLDEN=write` rewrites the
/// goldens; the expectations below are what keeps them honest.
final class BoardReviewTests: XCTestCase {
  typealias V = BoardReview.Verdict

  /// Each fixture's findings as (check, verdict), in report order. The two 2026-11-23 iPad sessions and the one of
  /// 2026-11-22 are the manual review's verdict (~/tmp/agent/notes/ipad-writing-review-2026-11-23.md): no bug; the
  /// 05:15 reflow as designed (story 1145); the 05:28 knob stretch unclear; the keeps clean; the selections lost to the
  /// popover as designed.
  static let expected: [String: [(Int, V)]] = [
    "ipad-2026-11-22-4d71": [],
    "ipad-2026-11-23-6bae-a": [(7, .asDesigned), (4, .asDesigned)],
    "ipad-2026-11-23-6bae-b": [(7, .asDesigned), (3, .unclear)],
    "check1-fires": [(1, .bug)],
    "check1-clean": [],
    "check1-header-line": [],
    "check2-fires": [(2, .bug)],
    "check2-clean": [],
    "check2-own-pen": [],
    "check2-touching": [],
    "check2-drop-room": [],
    "check2-drop-no-room": [(2, .bug)],
    "check3-fires": [(3, .bug), (4, .bug)],
    "check3-drag-own": [],
    "check3-room-asked": [],
    "check3-room-wrong": [(3, .bug)],
    "check3-tolerance": [],
    "check3-vhae": [(3, .bug)],
    "check3-knob-stretch": [(3, .unclear)],
    "check4-eg7v": [(3, .unclear), (4, .bug)],
    "check4-apart": [(4, .asDesigned)],
    "check4-selected-both": [],
    "check5-eysh": [(5, .bug)],
    "check5-clean": [],
    "check5-first-fold": [],
    "check5-unix-ms": [(5, .bug)],
    "check6-fires": [(6, .bug)],
    "check6-clean": [],
    "check6-9bll": [(6, .bug)],
    "check6-hide-only": [],
    "check6-reply-between": [],
    "check6-fold-undo": [],
    "check6-first-fold-undo": [],
    "check7-4nnh": [(7, .bug)],
    "check7-put-back": [(7, .asDesigned)],
    "check7-not-observed": [],
    "check7-approximate": [(7, .unclear)],
    "check8-fires": [(8, .bug)],
    "check8-approximate": [(8, .unclear)],
    "check8-clean": [],
    "check9-pbvt": [(9, .bug)],
    "check9-dell": [(9, .bug)],
    "check9-healed": [(9, .asDesigned)],
    "check9-approximate": [(9, .unclear)],
  ]

  static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
    "Fixtures/board-reviews")

  private func record(_ name: String) throws -> BoardSessionRecord {
    try BoardSessionRecord(jsonl: Data(contentsOf: Self.folder.appendingPathComponent("\(name).jsonl")))
  }

  func testEveryFixtureIsListed() throws {
    let files = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path).filter { $0.hasSuffix(".jsonl") }
    XCTAssertEqual(Set(files.map { String($0.dropLast(6)) }), Set(Self.expected.keys))
  }

  func testEachFixtureGivesItsChecksFindings() throws {
    for (name, want) in Self.expected {
      let report = BoardReview.run(try record(name))
      let got = report.findings.map { "\($0.check) \($0.verdict.rawValue)" }
      // Report order is by step, then check; compare as the sorted pairs so the table reads by story.
      XCTAssertEqual(got.sorted(), want.map { "\($0.0) \($0.1.rawValue)" }.sorted(), name)
    }
  }

  func testTheManualReviewsVerdictHasNoBug() throws {
    for name in ["ipad-2026-11-22-4d71", "ipad-2026-11-23-6bae-a", "ipad-2026-11-23-6bae-b"] {
      let report = BoardReview.run(try record(name))
      XCTAssertFalse(report.findings.contains { $0.verdict == .bug }, name)
      XCTAssertTrue(report.checks.allSatisfy { $0.sight == .checked }, name)
    }
    let a = BoardReview.run(try record("ipad-2026-11-23-6bae-a"))
    let reflow = try XCTUnwrap(a.findings.first { $0.check == 4 })
    XCTAssertEqual(reflow.story, 1145)
    XCTAssertEqual(reflow.evidence.first { $0.key == "went back" }?.value, "igor")
    let b = BoardReview.run(try record("ipad-2026-11-23-6bae-b"))
    let stretch = try XCTUnwrap(b.findings.first { $0.check == 3 })
    XCTAssertEqual(stretch.evidence.first { $0.key == "drag began" }?.value, "knob")
    XCTAssertEqual(stretch.evidence.first { $0.key == "size" }?.value, "13 wide, 2 high")
    XCTAssertEqual(BoardReviewText.note(b, asked: false), "Reviewed · 1 to look at")
  }

  func testEachFixtureMatchesItsGolden() throws {
    let write = ProcessInfo.processInfo.environment["BOARD_REVIEW_GOLDEN"] == "write"
    for name in Self.expected.keys.sorted() {
      let json = BoardReview.run(try record(name)).json()
      let url = Self.folder.appendingPathComponent("\(name).golden.json")
      if write {
        try (String(decoding: json, as: UTF8.self) + "\n").write(to: url, atomically: true, encoding: .utf8)
        continue
      }
      let golden = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
      XCTAssertEqual(String(decoding: json, as: UTF8.self), golden, name)
    }
  }

  func testAReviewIsTheSameTwice() throws {
    for name in Self.expected.keys {
      let record = try record(name)
      XCTAssertEqual(BoardReview.run(record), BoardReview.run(record), name)
    }
  }

  func testASurfaceThatDoesntSeeACheckSaysSo() throws {
    let web = BoardReview.run(try record("check7-not-observed"))
    XCTAssertEqual(web.checks[6].sight, .notChecked)
    XCTAssertTrue(BoardReviewText.larry(web).contains("check 7 not_checked"))
    let approx = BoardReview.run(try record("check8-approximate"))
    XCTAssertEqual(approx.checks[7].sight, .approximate)
    XCTAssertNotEqual(approx.findings.first?.verdict, .bug)
  }

  func testACleanReviewShowsNothingUnlessAsked() throws {
    let clean = BoardReview.run(try record("check2-clean"))
    XCTAssertNil(BoardReviewText.note(clean, asked: false))
    XCTAssertEqual(BoardReviewText.note(clean, asked: true), "Reviewed · clean")
    XCTAssertEqual(BoardReviewText.larry(clean), "Board review of session check2-clean on ipad, 1 steps: clean")
    let designed = BoardReview.run(try record("check7-put-back"))
    XCTAssertNil(BoardReviewText.note(designed, asked: false), "as designed doesn't count")
  }

  func testAFindingCopiesWithItsStepRuleAndEvidence() throws {
    let report = BoardReview.run(try record("check5-eysh"))
    let finding = try XCTUnwrap(report.findings.first)
    let text = BoardReviewText.copy(finding, of: report)
    XCTAssertTrue(text.hasPrefix("Board review: check 5 fold_swallowed, bug\n"), text)
    XCTAssertTrue(text.contains("step 2 at 3000: fold by menu"), text)
    XCTAssertTrue(text.contains("rule: story 1231"), text)
    XCTAssertTrue(text.contains("extra: 10 strokes: w0, w1, w2, w3, w4 and 5 more"), text)
    XCTAssertTrue(text.contains("held: 145 at its last fold, 155 now"), text)
    XCTAssertTrue(text.hasSuffix("board b-check5-eysh · session check5-eysh · ipad"), text)
    let larry = BoardReviewText.larry(report)
    XCTAssertTrue(larry.contains("check 5 fold_swallowed: 1 bug, 0 unclear, 0 as designed"), larry)
    XCTAssertTrue(larry.contains(text), larry)
  }

  func testAnUnreadableRecordSaysWhy() {
    XCTAssertThrowsError(try BoardSessionRecord(jsonl: Data())) { error in
      XCTAssertEqual("\(error)", "a record starts with its header")
    }
    let wrong = Data(#"{"record":2,"board":"b","session":"s","surface":"ipad","ink":[]}"#.utf8)
    XCTAssertThrowsError(try BoardSessionRecord(jsonl: wrong)) { error in
      XCTAssertEqual("\(error)", "record version 2, this review reads 1")
    }
  }
}
