import Foundation
import XCTest

@testable import ContextCore

final class WhiteboardStreamTests: XCTestCase {
  private let circle = #"{"kind": "circle", "cx": 50, "cy": 50, "r": 10}"#
  private let line = #"{"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9}"#
  private let last = #"{"done": true, "ms": 2100}"#
  /// cockpit#85's own line: sent instead of `done` when the model fails after the stream has started.
  private let failed = #"{"error": "the model took too long", "ms": 2400}"#

  private func stream() -> WhiteboardStream {
    WhiteboardStream(status: 200, contentType: "application/x-ndjson")
  }

  /// Every mark `text` completes, in order.
  private func feed(_ reader: inout WhiteboardStream, _ text: String) -> [WhiteboardTurn.Shape] {
    text.utf8.compactMap { reader.take($0) }
  }

  func testEachLineIsAMarkAsItsNewlineArrives() {
    var reader = stream()
    XCTAssertTrue(reader.streaming)
    XCTAssertEqual(feed(&reader, circle).count, 0, "no newline yet")
    XCTAssertEqual(feed(&reader, "\n").map(\.kind), [.ellipse])
    XCTAssertEqual(feed(&reader, line + "\n" + last + "\n").map(\.kind), [.line])
    XCTAssertTrue(reader.done)
    XCTAssertEqual(reader.answer(), .shapes(reader.shapes))
    XCTAssertEqual(reader.shapes.count, 2)
  }

  func testALineSplitAcrossReadsIsOneMark() {
    var reader = stream()
    let split = circle.index(circle.startIndex, offsetBy: 9)
    XCTAssertEqual(feed(&reader, String(circle[..<split])).count, 0)
    XCTAssertEqual(feed(&reader, String(circle[split...]) + "\n").count, 1)
  }

  func testUnknownLinesAreSkipped() {
    var reader = stream()
    let body = """
      not json
      [1, 2]

      {"kind": "hologram", "x": 1}
      {"status": "thinking"}
      \(circle)

      """
    XCTAssertEqual(feed(&reader, body).map(\.kind), [.ellipse])
    XCTAssertFalse(reader.done)
  }

  func testALastLineWithNoNewlineStillCounts() {
    var reader = stream()
    _ = feed(&reader, circle)
    XCTAssertEqual(reader.finish()?.kind, .ellipse)
    XCTAssertEqual(reader.shapes.count, 1)
  }

  func testHalfALineAtTheEndIsNothing() {
    var reader = stream()
    _ = feed(&reader, #"{"kind": "circ"#)
    XCTAssertNil(reader.finish())
    XCTAssertEqual(reader.answer(), .away(reason: "the answer ended early"))
  }

  func testLinesAfterTheLastAreIgnored() {
    var reader = stream()
    XCTAssertEqual(feed(&reader, last + "\n" + circle + "\n").count, 0)
  }

  func testABrokenStreamKeepsItsMarksAndIsNoFailure() {
    var reader = stream()
    _ = feed(&reader, circle + "\n" + #"{"kind": "li"#)
    XCTAssertEqual(reader.answer(error: "connection lost"), .shapes(reader.shapes))
    XCTAssertEqual(reader.shapes.count, 1)
  }

  func testABrokenStreamBeforeAnyMarkIsAFailure() {
    var reader = stream()
    _ = feed(&reader, #"{"kind": "li"#)
    XCTAssertEqual(reader.answer(error: "connection lost"), .away(reason: "connection lost"))
  }

  func testAFinishedStreamWithNoMarksIsNothingToAdd() {
    var reader = stream()
    _ = feed(&reader, last + "\n")
    XCTAssertEqual(reader.answer(), .shapes([]))
  }

  func testAnErrorLineWithNoMarksIsItsReason() {
    var reader = stream()
    _ = feed(&reader, failed + "\n")
    XCTAssertEqual(reader.answer(), .away(reason: "the model took too long"))
    XCTAssertEqual(reader.broken(), "the model took too long")
  }

  func testAnErrorLineAfterAMarkEndsTheStreamAndNamesTheCut() {
    var reader = stream()
    XCTAssertEqual(feed(&reader, circle + "\n" + failed + "\n" + line + "\n").map(\.kind), [.ellipse])
    XCTAssertTrue(reader.done)
    XCTAssertEqual(reader.answer(), .shapes(reader.shapes))
    XCTAssertEqual(reader.broken(), "the model took too long")
  }

  func testWhatBrokeTheReading() {
    var finished = stream()
    _ = feed(&finished, circle + "\n" + last + "\n")
    XCTAssertNil(finished.broken(), "read to its last line")

    var cut = stream()
    _ = feed(&cut, circle + "\n")
    XCTAssertEqual(cut.broken(), "no last line")
    XCTAssertEqual(cut.broken(error: "connection lost"), "connection lost")

    var plain = WhiteboardStream(status: 200, contentType: "application/json")
    _ = feed(&plain, #"{"ok": true, "strokes": []}"#)
    XCTAssertNil(plain.broken(), "one JSON has no last line to miss")
  }

  /// A Cockpit that doesn't stream: its one JSON, with its newlines, reads as it always did.
  func testAPlainAnswerIsReadWhole() {
    var reader = WhiteboardStream(status: 200, contentType: "application/json")
    XCTAssertFalse(reader.streaming)
    let body = """
      {"ok": true,
       "strokes": [\(circle), \(line)]}

      """
    XCTAssertEqual(feed(&reader, body).count, 0)
    XCTAssertNil(reader.finish())
    guard case .shapes(let shapes) = reader.answer() else { return XCTFail("\(reader.answer())") }
    XCTAssertEqual(shapes.map(\.kind), [.ellipse, .line])
  }

  func testRefusalsAndTooSoonReadAsBefore() {
    var refused = WhiteboardStream(status: 400, contentType: "application/x-ndjson")
    _ = feed(&refused, #"{"ok": false, "error": "no picture"}"#)
    XCTAssertEqual(refused.answer(), .refused(status: 400, reason: "no picture"))
    XCTAssertEqual(WhiteboardStream(status: 429, contentType: nil).answer(), .tooSoon)
  }

  func testNoResponseAndAPlainAnswerCutOffAreAway() {
    XCTAssertEqual(WhiteboardStream(status: nil, contentType: nil).answer(error: "offline"), .away(reason: "offline"))
    var cut = WhiteboardStream(status: 200, contentType: "application/json")
    _ = feed(&cut, #"{"ok": true, "stro"#)
    XCTAssertEqual(cut.answer(error: "connection lost"), .away(reason: "connection lost"))
  }
}
