import XCTest

@testable import BoardCore
@testable import BoardWasm

/// Story 1263 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 10): `bw_rows` gives the units
/// and rows the app's own outline has, on the Cockpit's recorded boards and on seeded ones, open and folded.
final class WebRowsTests: XCTestCase {
  /// The app's units and rows in the export's form, a kept text's glyphs named as the web board names the text. On
  /// the Mac the app's geometry is 64-bit, so its boxes are the edges the web board sent.
  private func expected(_ board: WebBoard) -> [String: Any] {
    let outline = board.app
    let n = WebBoard.webName
    let units = outline.units()
    let out: [[String: Any]] = units.map { unit in
      let b = unit.bounds
      let members = unit.members.map { outline.strokes[$0] }
      let object = unit.header == nil ? unit.tag.map(n) : nil
      var objectIds = members.filter { $0.points.isEmpty }.flatMap(\.ids).map(n)
      if let object, !objectIds.contains(object) { objectIds.append(object) }
      let names = members.flatMap(\.ids).map(n)
      return [
        "key": unit.header.map { "h:" + $0 } ?? object.map { "o:" + $0 } ?? "s:" + names[0], "names": names,
        "strokeIds": members.filter { !$0.points.isEmpty }.flatMap(\.ids), "objectIds": objectIds,
        "object": object.map { $0 as Any } ?? NSNull(), "tag": unit.tag.map { n($0) as Any } ?? NSNull(),
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
    return WebRows.rows(web.outline, texts: web.texts, groups: web.groups, edges: WebEdges.of(json: board.webJSON))
  }

  func testTheRecordedBoardsGetTheAppsUnitsAndRows() throws {
    for board in try WebBoard.recorded() {
      let got = try asked(board)
      XCTAssertTrue(sameJSONToAMillionth(got, expected(board)), "\(board.name): \(got)")
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

  /// Story 1263, version 13: the edges come back as the host sent them, worked out as the web board works a stroke's
  /// box (its points' extremes widened by half its pen), never through the rules' 32-bit geometry on wasm32.
  func testEdgesComeBackExactlyAsSent() throws {
    let a: [String: Any] = ["id": "a", "points": [[0.1, 100.1], [200.3, 100.7]], "width": 3.3]
    let b: [String: Any] = ["id": "b", "points": [[10.01, 140.123456789], [12.7, 141.9]], "width": 4.0]
    let t: [String: Any] = ["id": "t", "box": [0.3, 300.17, 99.9, 340.71]]
    let json: [String: Any] = ["strokes": [a, b], "boxes": [t], "groups": ["t": "t"], "headers": [Any]()]
    let wire = try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: json))
    let web = try WebOutline.parts(json: wire)
    let reply = WebRows.rows(web.outline, texts: web.texts, groups: web.groups, edges: WebEdges.of(json: wire))
    let units = try XCTUnwrap(reply["units"] as? [[String: Any]])
    let boxes = units.compactMap { $0["box"] as? [Double] }
    let half: Double = 3.3 / 2
    let boxA: [Double] = [0.1 - half, 100.1 - half, 200.3 + half, 100.7 + half]
    let boxB: [Double] = [10.01 - 2, 140.123456789 - 2, 12.7 + 2, 141.9 + 2]
    XCTAssertEqual(boxes[0], boxA)
    XCTAssertEqual(boxes[1], boxB)
    XCTAssertEqual(boxes[2], [0.3, 300.17, 99.9, 340.71])
    XCTAssertEqual(units.map { $0["key"] as? String }, ["s:a", "s:b", "o:t"])
    XCTAssertEqual(units[2]["objectIds"] as? [String], ["t"])
    XCTAssertEqual(units[2]["strokeIds"] as? [String], [])
    let rows = try XCTUnwrap(reply["rows"] as? [[String: Double]])
    XCTAssertEqual(rows.first?["top"], boxA[1])
    XCTAssertEqual(rows.last?["bottom"], 340.71)
  }
}
