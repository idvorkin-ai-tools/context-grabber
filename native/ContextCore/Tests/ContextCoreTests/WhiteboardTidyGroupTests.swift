import Foundation
import XCTest

@testable import ContextCore

/// Bead context-grabber-cg3 (stories 896, 991): Tidy overlaps never pulls a label out of the group Larry made with its
/// box. The oracle is the shapes spec's *Keep all and Tidy overlaps*: a group stays where it is.
final class WhiteboardTidyGroupTests: XCTestCase {
  typealias Tidy = WhiteboardTidy

  /// A stroke from (x, y) to (x + w, y + h), made at `t`, answering to `id`.
  private func stroke(_ id: String, t: Int64?, _ x: CGFloat, _ y: CGFloat, w: CGFloat, h: CGFloat) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y + h)]
    return BoardOps.Stroke(ids: [id], t: t, bounds: CGRect(x: x, y: y, width: w, height: h), points: points)
  }

  /// My line of writing, a box of Larry's round it and his label on the writing (its two glyphs made at 5000).
  private var board: [BoardOps.Stroke] {
    [
      stroke("mine", t: 1000, 100, 100, w: 300, h: 24),
      stroke("box", t: 4000, 80, 80, w: 360, h: 80),
      stroke("glyph-1", t: 5000, 150, 105, w: 60, h: 15),
      stroke("glyph-2", t: 5000, 210, 105, w: 60, h: 15),
    ]
  }

  private let label = BoardText(
    id: "larry-label", t: 5000, text: "Judge", font: .hand, size: 18, color: "#000000", glyphs: 2)

  /// Tidy as the app runs it: the labels laid out among the ink, how far each stroke moves by its place.
  private func tidy(_ strokes: [BoardOps.Stroke], _ laid: (labels: [String: [Int]], ink: [Int], grouped: Int))
    -> [Int: CGFloat]
  {
    let lines = laid.labels.mapValues { $0.map { strokes[$0].points } }
    let moves = Tidy.tidy(lines, among: laid.ink.map { strokes[$0].points })
    var out: [Int: CGFloat] = [:]
    for (id, dy) in moves { for i in laid.labels[id] ?? [] { out[i] = dy } }
    return out
  }

  func testAGroupedBoxAndLabelOverMyWritingStayTogether() {
    // #937's shape: the label grouped under its text's id, the box under its stroke's name.
    let groups = ["larry-label": "judge-block", "box": "judge-block"]
    let laid = Tidy.laid(board, known: [5000], texts: [label], groups: groups)
    XCTAssertTrue(laid.labels.isEmpty, "a grouped label is not Tidy's to move")
    XCTAssertEqual(laid.grouped, 1)
    XCTAssertTrue(tidy(board, laid).isEmpty, "neither the box nor its label moves")
  }

  func testALabelGroupedByItsStrokesNamesStaysToo() {
    let groups = ["box": "judge-block", "glyph-1": "judge-block", "glyph-2": "judge-block"]
    let laid = Tidy.laid(board, known: [5000], texts: [label], groups: groups)
    XCTAssertTrue(laid.labels.isEmpty)
    XCTAssertTrue(tidy(board, laid).isEmpty)
  }

  func testALabelWithOnlyOneGlyphGroupedStaysWhole() {
    let groups = ["box": "judge-block", "glyph-1": "judge-block"]
    let laid = Tidy.laid(board, known: [5000], groups: groups)
    XCTAssertTrue(laid.labels.isEmpty, "half a label never moves under its other half")
    XCTAssertEqual(laid.grouped, 1)
    XCTAssertTrue(tidy(board, laid).isEmpty)
  }

  func testTheSameLabelUngroupedStillMovesOffMyWriting() {
    let laid = Tidy.laid(board, known: [5000], texts: [label])
    XCTAssertEqual(laid.labels, ["5000": [2, 3]])
    XCTAssertEqual(laid.grouped, 0)
    let moves = tidy(board, laid)
    XCTAssertEqual(Set(moves.keys), [2, 3], "both glyphs move, the box and my writing don't")
    XCTAssertGreaterThan(moves[2] ?? 0, 0)
  }

  func testAGroupDissolvedByAnEraseIsALabelAgain() {
    // Story 854: once Igor erased part of the group its notes are gone, and the label is a label again.
    let laid = Tidy.laid(board, known: [5000], texts: [label], groups: [:])
    XCTAssertEqual(laid.labels.keys.sorted(), ["5000"])
  }

  func testAnotherLabelStillClearsAGroupedOne() {
    var strokes = board
    strokes.append(stroke("other", t: 6000, 150, 110, w: 100, h: 15))
    let groups = ["larry-label": "judge-block", "box": "judge-block"]
    let laid = Tidy.laid(strokes, known: [5000, 6000], texts: [label], groups: groups)
    XCTAssertEqual(laid.labels, ["6000": [4]])
    let moves = tidy(strokes, laid)
    XCTAssertEqual(Set(moves.keys), [4], "only the free label moves, under the group")
  }

  func testFoldedStrokesAreNeitherMovedNorInTheWay() {
    let laid = Tidy.laid(board, known: [5000], texts: [label], folded: [0])
    XCTAssertFalse(laid.ink.contains(0))
    XCTAssertEqual(laid.labels, ["5000": [2, 3]])
  }
}
