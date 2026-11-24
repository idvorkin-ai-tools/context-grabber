import XCTest

@testable import ContextCore

/// Story 1280 (bead context-grabber-xzmc, Igor 2026-11-24): only Larry's groups are not Igor's writing; a group Igor
/// made of his own ink is still his writing, and still moves whole.
final class BoardOutlineIgorGroupsTests: XCTestCase {
  private func stroke(_ id: String, _ points: [CGPoint]) -> BoardOps.Stroke {
    let box = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }.insetBy(dx: -1.5, dy: -1.5)
    return BoardOps.Stroke(ids: [id], t: nil, bounds: box, points: points, pen: 3)
  }

  private func letter(_ id: String, x: CGFloat, y: CGFloat) -> BoardOps.Stroke {
    stroke(id, [CGPoint(x: x, y: y + 24), CGPoint(x: x + 10, y: y), CGPoint(x: x + 20, y: y + 24)])
  }

  private func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  private func underline(_ id: String) -> BoardOps.Stroke {
    let wobble: [CGFloat] = [0, 0.8, -0.6, 1.1, -0.9, 0.4, -1.2, 0.7]
    let points = (0...12).map { i in
      CGPoint(x: 96 + CGFloat(i) * 6.3, y: 128 + (i == 0 || i == 12 ? 0 : wobble[i % wobble.count]))
    }
    return stroke(id, points)
  }

  /// A line of three letters at the top, grouped as `g`, with writing under it.
  private func board(mine: Set<String>) -> BoardOutline {
    let strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("c", x: 100, y: 180)
    let groups = ["h0": "g", "h1": "g", "h2": "g"]
    return BoardOutline(strokes: strokes, headers: [], groups: groups, mine: mine)
  }

  func testAGroupOfLarrysIsNotHisWriting() {
    var o = board(mine: [])
    XCTAssertEqual(o.row(at: 112)?.names, [], "a row of Larry's group has none of his writing")
    XCTAssertFalse(o.markHeader(at: 112, id: "x"))
    o.strokes.append(underline("under"))
    XCTAssertNil(o.inkHeader(newest: o.strokes.count - 1, id: "y"), "an underline under Larry's group makes no header")
  }

  func testAGroupIgorMadeIsStillHisWriting() throws {
    var o = board(mine: ["g"])
    XCTAssertEqual(o.row(at: 112)?.names, ["h0", "h1", "h2"])
    o.strokes.append(underline("under"))
    let made = try XCTUnwrap(o.inkHeader(newest: o.strokes.count - 1, id: "y"))
    XCTAssertEqual(made.kind, "underline")
    XCTAssertEqual(Set(try XCTUnwrap(o.header("y")).ids), ["h0", "h1", "h2", "under"])
  }

  func testAMarginTapMakesHisGroupAHeader() {
    var o = board(mine: ["g"])
    XCTAssertTrue(o.markHeader(at: 112, id: "x"))
  }

  func testHisGroupStillMovesWhole() {
    let o = board(mine: ["g"])
    let groups = ["h0": "g", "h1": "g", "h2": "g"]
    let item = BoardOps.items(strokes: o.strokes, groups: groups).first { $0.tag == "g" }
    XCTAssertEqual(item?.members.count, 3, "his group is still one thing that moves whole")
  }
}
