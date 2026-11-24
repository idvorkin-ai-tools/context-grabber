import XCTest

@testable import BoardCore
@testable import BoardWasm

/// Story 1280 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 18): the outline's `"mine"`
/// names the groups Igor made, which stay his writing; left out, every group is Larry's.
final class WebMineGroupsTests: XCTestCase {
  private func outline(mine: [String]?) throws -> BoardOutline {
    func letter(_ id: String, _ x: Double) -> [String: Any] {
      ["id": id, "points": [[x, 124], [x + 10, 100], [x + 20, 124]], "width": 3]
    }
    var json: [String: Any] = [
      "strokes": [letter("a", 100), letter("b", 124), letter("c", 148)],
      "groups": ["a": "g", "b": "g", "c": "g"],
    ]
    if let mine { json["mine"] = mine }
    return try WebOutline.outline(json: json)
  }

  func testGroupsAreLarrysUnlessNamedMine() throws {
    XCTAssertEqual(
      WebOutline.row(try outline(mine: nil), at: 112)["row"].flatMap { ($0 as? [String: Any])?["names"] as? [String] },
      [])
    XCTAssertEqual(
      WebOutline.row(try outline(mine: ["g"]), at: 112)["row"].flatMap {
        ($0 as? [String: Any])?["names"] as? [String]
      },
      ["a", "b", "c"])
  }
}
