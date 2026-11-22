import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the shapes spec's *Keep all and Tidy overlaps* (story 896), after the Cockpit web board's `tidy`
/// (assets/ink/test_board.mjs): Tidy moves only the labels that sit on ink. Unlike the web board, his ink never moves.
/// Keep all no longer lays labels out (bead context-grabber-yqau): its rule is `WhiteboardKeepAllTests`.
final class WhiteboardTidyTests: XCTestCase {
  typealias Tidy = WhiteboardTidy

  /// A line of "writing" across x0...x0+w, from y to y+24.
  private func writing(_ y: CGFloat, _ x0: CGFloat = 100, _ w: CGFloat = 300) -> [CGPoint] {
    stride(from: x0, through: x0 + w, by: 20).map { CGPoint(x: $0, y: y + (Int($0 / 20) % 2 == 1 ? 24 : 0)) }
  }

  /// A label's letters as a box of strokes, x...x+w, y...y+h.
  private func label(_ x: CGFloat, _ y: CGFloat, w: CGFloat = 120, h: CGFloat = 20) -> [[CGPoint]] {
    [[CGPoint(x: x, y: y), CGPoint(x: x + w, y: y + h)], [CGPoint(x: x, y: y + h), CGPoint(x: x + w, y: y)]]
  }

  func testALabelOnBarePaperStaysWhereItIs() {
    XCTAssertEqual(Tidy.clearing(Tidy.bounds(label(100, 300)), of: [writing(100)]), 0)
  }

  func testALabelOnInkMovesUnderIt() {
    let dy = Tidy.clearing(Tidy.bounds(label(150, 110)), of: [writing(100)])
    XCTAssertEqual(dy, 124 + Tidy.air - 110, "its top under the writing's bottom, with air")
  }

  func testTouchingIsNotSittingOn() {
    XCTAssertEqual(Tidy.clearing(Tidy.bounds(label(150, 124)), of: [writing(100)]), 0)
  }

  func testALabelMovedOntoMoreInkKeepsGoingUntilClear() {
    let dy = Tidy.clearing(Tidy.bounds(label(150, 110)), of: [writing(100), writing(150)])
    XCTAssertEqual(110 + dy, 174 + Tidy.air, "under the second line, the first clear space")
  }

  func testInkBesideTheLabelIsNotUnderIt() {
    XCTAssertEqual(Tidy.clearing(Tidy.bounds(label(500, 110)), of: [writing(100, 100, 300)]), 0)
  }

  func testTidyMovesOnlyTheLabelsThatSitOnInk() {
    let labels = ["on": label(150, 110), "clear": label(100, 400)]
    let moves = Tidy.tidy(labels, among: [writing(100)])
    XCTAssertEqual(moves["on"], 124 + Tidy.air - 110)
    XCTAssertNil(moves["clear"])
  }

  func testTidySeparatesTwoLabelsOnEachOther() {
    let labels = ["top": label(100, 300), "lower": label(120, 310)]
    let moves = Tidy.tidy(labels, among: [])
    XCTAssertNil(moves["top"], "the higher one stays")
    XCTAssertEqual(310 + (moves["lower"] ?? 0), 320 + Tidy.air, "the lower goes under it")
  }

  func testTidyWithNothingOverlappingMovesNothing() {
    XCTAssertEqual(Tidy.tidy(["a": label(100, 300)], among: [writing(100)]), [:])
  }

  func testTidyTwiceChangesNothing() {
    let labels = ["a": label(150, 110), "b": label(160, 120), "c": label(100, 400)]
    let ink = [writing(100)]
    let moves = Tidy.tidy(labels, among: ink)
    XCTAssertEqual(moves.count, 2)
    let tidied = labels.mapValues { $0 }.reduce(into: [String: [[CGPoint]]]()) { out, entry in
      out[entry.key] = entry.value.map { line in line.map { CGPoint(x: $0.x, y: $0.y + (moves[entry.key] ?? 0)) } }
    }
    XCTAssertEqual(Tidy.tidy(tidied, among: ink), [:])
  }
}
