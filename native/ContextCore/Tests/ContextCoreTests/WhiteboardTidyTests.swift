import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the shapes spec's *Keep all and Tidy overlaps* (stories 895, 896), after the Cockpit web board's
/// `keepAll` and `tidy` (assets/ink/test_board.mjs): marks kept together land in order, and Tidy moves only the labels
/// that sit on ink. Unlike the web board, his ink never moves.
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

  func testKeptTogetherTheyLandInTheOrderTheyWereDrawn() {
    // Larry's three labels down the page; the first lands on a line of his writing.
    let marks = [
      Tidy.Mark(id: "c", lines: label(100, 200), label: true),
      Tidy.Mark(id: "a", lines: label(100, 110), label: true),
      Tidy.Mark(id: "b", lines: label(100, 150), label: true),
    ]
    let moves = Tidy.keepAll(marks, over: [writing(100)])
    let a = moves["a"] ?? 0
    let b = moves["b"] ?? 0
    let c = moves["c"] ?? 0
    XCTAssertEqual(110 + a, 124 + Tidy.air, "the first moves under the writing")
    XCTAssertGreaterThanOrEqual(150 + b, 110 + a + 20, "the second still under the first")
    XCTAssertGreaterThan(200 + c, 150 + b, "and the third under the second")
    XCTAssertGreaterThanOrEqual(b, a, "a mark after one that moved moves with it")
  }

  func testAShapeKeptWithLabelsMovesOnlyWithThoseAboveIt() {
    let marks = [
      Tidy.Mark(id: "label", lines: label(100, 110), label: true),
      Tidy.Mark(id: "arrow", lines: [[CGPoint(x: 150, y: 200), CGPoint(x: 250, y: 200)]], label: false),
      Tidy.Mark(id: "above", lines: [[CGPoint(x: 150, y: 50), CGPoint(x: 250, y: 50)]], label: false),
    ]
    let moves = Tidy.keepAll(marks, over: [writing(100)])
    XCTAssertEqual(moves["above"], 0)
    XCTAssertEqual(moves["arrow"], moves["label"], "below the label that moved, it moves with it")
    XCTAssertGreaterThan(moves["label"] ?? 0, 0)
  }

  func testAShapeOnInkStaysOnIt() {
    let circle = Tidy.Mark(id: "circle", lines: [writing(100)], label: false)
    XCTAssertEqual(
      Tidy.keepAll([circle], over: [writing(100)])["circle"], 0, "a mark round his words is meant to be there")
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
