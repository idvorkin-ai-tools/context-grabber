import XCTest

@testable import ContextCore

/// A header, indented lines and the lines after, for the fold marker's and the fold erase's tests.
enum BoardFoldFixture {
  static func letter(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 24) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + h), CGPoint(x: x + w / 2, y: y), CGPoint(x: x + w, y: y + h)]
    return BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: w, height: h), points: points, pen: 3)
  }

  /// A word of three letters, 4 points apart: `<id>0`, `<id>1`, `<id>2`.
  static func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  static func header(_ id: String) -> BoardHeader { BoardHeader(id: id, ids: (0..<3).map { "\(id)\($0)" }) }

  /// A header, two indented lines, and a line back at its indent; folded, the last line sits at 180.
  static var start: [BoardOps.Stroke] {
    word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("b", x: 140, y: 180) + word("c", x: 100, y: 220)
  }

  static func folded() -> BoardOutline {
    var o = BoardOutline(strokes: start, headers: [header("h")])
    o.fold("h")
    return o
  }

  /// Outer header, an indented inner header with deeper lines, a line back under the outer, and the next top header
  /// with a line of its own.
  static var nested: BoardOutline {
    let strokes =
      word("o", x: 100, y: 100) + word("i", x: 140, y: 140) + word("d", x: 180, y: 180) + word("e", x: 140, y: 220)
      + word("p", x: 100, y: 260) + word("q", x: 140, y: 300)
    return BoardOutline(strokes: strokes, headers: [header("o"), header("i"), header("p")])
  }
}

/// Stories 900, 901: a folded header's "▸ N lines folded", in the web board's words and place (`foldMarkerBox`).
final class BoardFoldMarkerTests: XCTestCase {
  private typealias F = BoardFoldFixture

  func testTheMarkerSaysHowManyLinesAndSitsBesideTheHeader() throws {
    XCTAssertEqual(BoardOutline.markerText(lines: 1), "▸ 1 line folded")
    XCTAssertEqual(BoardOutline.markerText(lines: 3), "▸ 3 lines folded")
    XCTAssertTrue(BoardOutline(strokes: F.start, headers: [F.header("h")]).markers.isEmpty, "an open header has none")
    let marker = try XCTUnwrap(F.folded().markers.first)
    XCTAssertEqual(marker.header, "h")
    XCTAssertEqual(marker.text, "▸ 2 lines folded")
    // The header's row ends at 168 and its middle is 112: the words start 14 past it, on a baseline 5 below the middle.
    XCTAssertEqual(marker.origin, CGPoint(x: 182, y: 117))
    XCTAssertEqual(marker.box.minX, 178)
    XCTAssertEqual(marker.box.minY, 100)
    XCTAssertEqual(marker.box.maxY, 120)
    XCTAssertEqual(marker.box.maxX, 168 + 18 + 16 * 14 * 0.55, accuracy: 0.001)
  }

  func testAFoldFoldedAwayInsideAnotherShowsNoMarker() {
    var o = F.nested
    o.fold("i")
    XCTAssertEqual(o.markers.map(\.header), ["i"])
    o.fold("o")
    XCTAssertEqual(o.markers.map(\.header), ["o"], "only the outer one shows")
  }
}
