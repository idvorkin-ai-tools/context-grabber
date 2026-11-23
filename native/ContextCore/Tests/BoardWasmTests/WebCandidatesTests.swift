import BoardCore
import XCTest

@testable import BoardWasm

/// Story 1267 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 9): `bw_candidates` offers the
/// lines the app's own outline offers, on the Cockpit's recorded boards and on seeded ones.
final class WebCandidatesTests: XCTestCase {
  /// The app's candidates in the export's form.
  private func expected(_ outline: BoardOutline) -> [[String: Any]] {
    outline.candidates().map { c in
      [
        "y": Double(c.y), "top": Double(c.box.minY), "bottom": Double(c.box.maxY), "left": Double(c.box.minX),
        "right": Double(c.box.maxX), "why": c.why.rawValue,
      ]
    }
  }

  private func asked(_ board: WebBoard, declined: Set<String> = []) throws -> [[String: Any]] {
    let web = try board.web()
    let reply = WebCandidates.candidates(web.outline, texts: web.texts, groups: web.groups, declined: declined)
    return try XCTUnwrap(reply["candidates"] as? [[String: Any]])
  }

  private func same(_ a: [[String: Any]], _ b: [[String: Any]]) -> Bool { sameJSON(a, b) }

  func testTheRecordedBoardsGetTheAppsCandidates() throws {
    for var board in try WebBoard.recorded() {
      XCTAssertTrue(same(try asked(board), expected(board.app)), board.name)
      // Its first row of ink made a header: the same again.
      guard let y = board.strokes.first(where: { !$0.points.isEmpty })?.bounds.midY,
        let row = board.app.row(at: y), !row.names.isEmpty
      else { continue }
      board.headers = [BoardHeader(id: "H", ids: row.names)]
      XCTAssertTrue(same(try asked(board), expected(board.app)), "\(board.name) with a header")
    }
  }

  func testSeededBoardsGetTheAppsCandidatesOpenAndFolded() throws {
    var offered = (big: 0, underline: 0)
    for seed in UInt64(1)...60 {
      var board = try WebBoard.seeded(seed)
      let want = expected(board.app)
      let got = try asked(board)
      XCTAssertTrue(same(got, want), "\(board.name): \(got) against \(want)")
      offered.big += want.filter { $0["why"] as? String == "big" }.count
      offered.underline += want.filter { $0["why"] as? String == "underline" }.count
      for header in board.headers { _ = board.fold(header.id) }
      XCTAssertTrue(same(try asked(board), expected(board.app)), "\(board.name) folded")
    }
    XCTAssertGreaterThan(offered.big, 5, "the seeded boards offer big lines")
    XCTAssertGreaterThan(offered.underline, 5, "and underlined ones")
  }

  func testADeclinedLineIsNotOffered() throws {
    for seed in UInt64(1)...20 {
      let board = try WebBoard.seeded(seed)
      guard let first = board.app.candidates().first, let row = board.app.row(at: first.y) else { continue }
      let declined = BoardOutline(
        strokes: board.strokes, headers: board.headers, texts: board.texts, groups: board.groups,
        declined: Set(row.names))
      XCTAssertTrue(same(try asked(board, declined: Set(row.names)), expected(declined)), board.name)
      XCTAssertFalse(
        try asked(board, declined: Set(row.names)).contains { $0["y"] as? Double == Double(first.y) }, board.name)
    }
  }
}
