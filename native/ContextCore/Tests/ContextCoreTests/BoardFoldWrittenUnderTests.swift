import XCTest

@testable import ContextCore

/// Story 1231 (bead context-grabber-eysh, Cockpit bead cockpit-9ik): ink written under a folded header stays outside
/// its fold. The repro is the Cockpit's .ink script: "Notes" underlined on row 2, "first point" and "second point"
/// unindented under it (10 and 11 strokes), fold, "new thought" (10 strokes) written under the folded header, unfold,
/// fold again: 21 hidden, not 31.
final class BoardFoldWrittenUnderTests: XCTestCase {
  private func stroke(_ id: String, _ points: [CGPoint]) -> BoardOps.Stroke {
    let box = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }.insetBy(dx: -1.5, dy: -1.5)
    return BoardOps.Stroke(ids: [id], t: nil, bounds: box, points: points, pen: 3)
  }

  /// `n` letter-sized carets on row `row` (40 points a row), 4 points apart: one word to the outline.
  private func write(_ id: String, row: Int, n: Int, x: CGFloat = 100) -> [BoardOps.Stroke] {
    let y = CGFloat(row) * BoardOutline.line + 8
    return (0..<n).map { i in
      let left = x + CGFloat(i) * 24
      return stroke(
        "\(id)\(i)", [CGPoint(x: left, y: y + 24), CGPoint(x: left + 10, y: y), CGPoint(x: left + 20, y: y + 24)])
    }
  }

  private func hiddenCount(_ o: BoardOutline) -> Int { o.strokes.filter(\.hidden).count }

  private func hidden(_ o: BoardOutline, _ id: String) -> Bool {
    o.strokes.first { $0.ids.contains(id) }?.hidden ?? false
  }

  /// The script up to the first fold: the header made by its underline, its two unindented lines folded.
  private func folded() throws -> BoardOutline {
    var strokes = write("notes", row: 2, n: 5) + write("first", row: 3, n: 10) + write("second", row: 4, n: 11)
    strokes.append(stroke("under", [CGPoint(x: 96, y: 116), CGPoint(x: 160, y: 117), CGPoint(x: 220, y: 116)]))
    var o = BoardOutline(strokes: strokes, headers: [])
    let under = try XCTUnwrap(o.strokes.firstIndex { $0.ids.contains("under") })
    XCTAssertEqual(try XCTUnwrap(o.inkHeader(newest: under, id: "notes")).kind, "underline")
    XCTAssertTrue(o.fold("notes"))
    XCTAssertEqual(hiddenCount(o), 21)
    return o
  }

  func testInkWrittenUnderAFoldedHeaderStaysOutsideTheNextFold() throws {
    var o = try folded()
    o.strokes += write("new", row: 4, n: 10)
    XCTAssertTrue(o.unfold("notes"))
    XCTAssertTrue(o.fold("notes"))
    XCTAssertEqual(hiddenCount(o), 21, "the fold takes only the two points")
    XCTAssertFalse(hidden(o, "new0") || hidden(o, "new9"), "the new thought shows")
    XCTAssertTrue(hidden(o, "first0") && hidden(o, "second10"))
  }

  /// The header goes to the web board and to storage as JSON: what keeps the new line out must survive the trip.
  func testTheEndSurvivesTheHeadersJSON() throws {
    var o = try folded()
    o.strokes += write("new", row: 4, n: 10)
    XCTAssertTrue(o.unfold("notes"))
    let data = try JSONEncoder().encode(o.headers)
    let back = BoardOutline(strokes: o.strokes, headers: try JSONDecoder().decode([BoardHeader].self, from: data))
    var again = back
    XCTAssertTrue(again.fold("notes"))
    XCTAssertEqual(hiddenCount(again), 21)
  }

  func testAnUnfoldWithNothingWrittenChangesNoSection() throws {
    var o = try folded()
    let before = try XCTUnwrap(o.header("notes"))
    XCTAssertTrue(o.unfold("notes"))
    var after = try XCTUnwrap(o.header("notes"))
    after.fold = before.fold
    XCTAssertEqual(after, before, "the header is as it was")
    XCTAssertTrue(o.fold("notes"))
    XCTAssertEqual(hiddenCount(o), 21)
  }

  func testErasingTheNewInkLetsTheSectionRunOn() throws {
    var o = try folded()
    o.strokes += write("new", row: 4, n: 10)
    XCTAssertTrue(o.unfold("notes"))
    o.strokes.removeAll { $0.ids.contains { $0.hasPrefix("new") } }
    o.strokes += write("later", row: 6, n: 4)
    XCTAssertTrue(o.fold("notes"))
    XCTAssertTrue(hidden(o, "later0"), "with the new ink gone, the unindented section runs on")
  }
}
