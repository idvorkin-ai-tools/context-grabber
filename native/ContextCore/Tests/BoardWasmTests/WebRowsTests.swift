import XCTest

@testable import BoardCore
@testable import BoardWasm

/// Story 1263 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 10): `bw_rows` gives the units
/// and rows the app's own outline has, on the Cockpit's recorded boards and on seeded ones, open and folded.
final class WebRowsTests: XCTestCase {
  /// The app's units and rows in the export's form, a kept text's glyphs named as the web board names the text.
  private func expected(_ board: WebBoard) -> [String: Any] {
    let outline = board.app
    let units = outline.units()
    let out: [[String: Any]] = units.map { unit in
      let b = unit.bounds
      return [
        "names": unit.members.flatMap { outline.strokes[$0].ids }.map(WebBoard.webName),
        "tag": unit.tag.map { WebBoard.webName($0) as Any } ?? NSNull(),
        "header": unit.header.map { $0 as Any } ?? NSNull(),
        "box": [Double(b.minX), Double(b.minY), Double(b.maxX), Double(b.maxY)],
      ]
    }
    let rows: [[String: Any]] = BoardRoom.rows(units.map(\.bounds)).map {
      ["top": Double($0.lowerBound), "bottom": Double($0.upperBound)]
    }
    return ["units": out, "rows": rows]
  }

  private func asked(_ board: WebBoard) throws -> [String: Any] {
    let web = try board.web()
    return WebRows.rows(web.outline, texts: web.texts, groups: web.groups)
  }

  func testTheRecordedBoardsGetTheAppsUnitsAndRows() throws {
    for board in try WebBoard.recorded() {
      let got = try asked(board)
      XCTAssertTrue(sameJSON(got, expected(board)), "\(board.name): \(got)")
      XCTAssertFalse((got["units"] as? [Any] ?? []).isEmpty, board.name)
    }
  }

  func testSeededBoardsGetTheAppsUnitsAndRowsOpenAndFolded() throws {
    var folded = 0
    for seed in UInt64(1)...60 {
      var board = try WebBoard.seeded(seed)
      XCTAssertTrue(sameJSON(try asked(board), expected(board)), board.name)
      for header in board.headers where board.fold(header.id) { folded += 1 }
      let got = try asked(board)
      XCTAssertTrue(sameJSON(got, expected(board)), "\(board.name) folded: \(got)")
    }
    XCTAssertGreaterThan(folded, 10, "the seeded boards fold")
  }
}
