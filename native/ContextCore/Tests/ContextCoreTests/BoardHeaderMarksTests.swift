import XCTest

@testable import ContextCore

/// Stories 1040, 1041 (#1004): every header's ▾ in one spot at the margin's left, standing on its line's baseline, and
/// a margin tap within 22 points of its middle on it. The # row is the iPad's own, from the 2026-11-20 session log
/// (board a7ccb167, `paper_ink` added boxes): "#Affirmations", its # written at x 6–33, in the margin.
final class BoardHeaderMarksTests: XCTestCase {
  /// A stroke filling `box`, corner to corner: the log has the boxes, not the paths.
  private func stroke(_ id: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> BoardOps.Stroke {
    let box = CGRect(x: x, y: y, width: w, height: h)
    return BoardOps.Stroke(
      ids: [id], t: nil, bounds: box, points: [CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.minY)],
      pen: 3)
  }

  /// "#Affirmations" as the iPad logged it: the word's strokes first, then the # left of it.
  private var affirmations: [BoardOps.Stroke] {
    let word: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
      (29, 377, 18, 25), (35, 391, 12, 5), (48, 379, 13, 21), (49, 390, 13, 5), (62, 378, 20, 24), (63, 390, 15, 6),
      (78, 391, 11, 12), (82, 389, 16, 14), (101, 390, 27, 10), (125, 376, 45, 23), (162, 386, 23, 13),
      (186, 381, 44, 19),
    ]
    let hash: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
      (11, 381, 6, 22), (18, 382, 7, 20), (6, 387, 27, 8), (7, 396, 25, 8),
    ]
    return word.enumerated().map { stroke("w\($0)", $1.0, $1.1, $1.2, $1.3) }
      + hash.enumerated().map { stroke("#\($0)", $1.0, $1.1, $1.2, $1.3) }
  }

  func testTheMarkStandsOnTheBaselineAtTheMarginsLeftOverAHashInTheMargin() throws {
    let strokes = affirmations
    let header = BoardHeader(id: "a", ids: strokes.flatMap(\.ids))
    let o = BoardOutline(strokes: strokes, headers: [header])
    let mark = try XCTUnwrap(o.headerMarks.first)
    XCTAssertEqual(mark.text, "▾")
    XCTAssertEqual(mark.box.minX, BoardOutline.headerMarkLeft, "the margin's left, wherever the # is")
    // The row runs 376–404; its letters stand on about 400, not its middle (390) the old ▾ sat at.
    XCTAssertEqual(mark.baseline, 401, accuracy: 3, "on the baseline")
    XCTAssertEqual(mark.box.maxY, mark.baseline, "the mark's foot on the baseline")
    XCTAssertEqual(mark.box.height, BoardOutline.headerMarkSize)
  }

  func testHeadersAtDifferentIndentsShareOneSpotAcross() throws {
    let near = (0..<3).map { stroke("n\($0)", 80 + CGFloat($0) * 24, 100, 20, 24) }
    let far = (0..<3).map { stroke("f\($0)", 200 + CGFloat($0) * 24, 200, 20, 24) }
    // A g's tail doesn't pull the baseline down.
    let tail = stroke("f3", 272, 200, 20, 36)
    let o = BoardOutline(
      strokes: near + far + [tail],
      headers: [
        BoardHeader(id: "n", ids: near.flatMap(\.ids)), BoardHeader(id: "f", ids: (far + [tail]).flatMap(\.ids)),
      ])
    let marks = o.headerMarks
    XCTAssertEqual(marks.count, 2)
    XCTAssertEqual(Set(marks.map(\.box.minX)), [BoardOutline.headerMarkLeft], "one spot across")
    XCTAssertEqual(marks.first { $0.header == "n" }?.baseline, 124)
    XCTAssertEqual(marks.first { $0.header == "f" }?.baseline, 224, "the tail is left out")
  }

  func testATapWithin22PointsOfTheMarksMiddleIsOnItsHeader() throws {
    // One thin flat stroke: its row alone reaches 16 points above it, the mark 22 from its middle.
    let line = stroke("l", 100, 300, 200, 4)
    let o = BoardOutline(strokes: [line], headers: [BoardHeader(id: "h", ids: ["l"])])
    let mid = try XCTUnwrap(o.headerMarks.first).box.midY
    XCTAssertEqual(o.header(at: mid - 22)?.id, "h", "the top of a 44-point target")
    XCTAssertEqual(o.header(at: mid + 22)?.id, "h", "the bottom of it")
    XCTAssertNil(o.header(at: mid - 23), "past the mark and the row's own reach")
  }

  func testAFoldedHeadersMarkSaysItsLinesInTheSameSpot() throws {
    let head = (0..<3).map { stroke("h\($0)", 100 + CGFloat($0) * 24, 100, 20, 24) }
    let body = (0..<3).map { stroke("b\($0)", 140 + CGFloat($0) * 24, 140, 20, 24) }
    var o = BoardOutline(strokes: head + body, headers: [BoardHeader(id: "h", ids: head.flatMap(\.ids))])
    XCTAssertTrue(o.fold("h"))
    let mark = try XCTUnwrap(o.headerMarks.first)
    XCTAssertTrue(mark.folded)
    XCTAssertEqual(mark.text, "▸ 1")
    XCTAssertEqual(mark.box.minX, BoardOutline.headerMarkLeft)
    XCTAssertLessThanOrEqual(mark.box.maxX, BoardMargin.width, "inside the margin")
  }
}
