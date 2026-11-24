import XCTest

@testable import BoardCore
@testable import BoardWasm

/// Story 1264 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 11): `bw_opening` opens a fold
/// as the app's own outline opens it, on seeded boards folded and then written under.
final class WebOpeningTests: XCTestCase {
  /// The app's opening in the export's form, a kept text's glyphs named as the web board names the text.
  private func expected(_ board: WebBoard, _ id: String) -> [String: Any] {
    var copy = board.app
    guard let opened = copy.opening(id) else { return ["opening": NSNull()] }
    var moves: [String: Double] = [:]
    var shown: [String] = []
    for (was, now) in zip(board.strokes, copy.strokes) {
      let dy = now.bounds.minY - was.bounds.minY
      if dy != 0 { for name in now.ids { moves[WebBoard.webName(name)] = Double(dy) } }
      if was.hidden && !now.hidden { shown += now.ids.map(WebBoard.webName) }
    }
    let ends: Any = copy.header(id)?.ends.map { $0.map(WebBoard.webName) as Any } ?? NSNull()
    return [
      "opening": [
        "top": Double(opened.top), "slide": Double(opened.slide), "moves": moves, "shown": shown, "ends": ends,
      ] as [String: Any]
    ]
  }

  private func asked(_ board: WebBoard, _ id: String) throws -> [String: Any] {
    WebOpening.opening(try board.web().outline, id)
  }

  /// A stroke written a line under header `id`'s row, indented, as Igor writes under a folded header.
  private func writeUnder(_ board: inout WebBoard, _ id: String) -> String? {
    guard let header = board.app.header(id), let box = board.app.box(header) else { return nil }
    let y = (box.maxY + 26).rounded()
    let name = "w-\(id)"
    let points = [CGPoint(x: box.minX + 60, y: y), CGPoint(x: box.minX + 160, y: y)]
    board.strokes.append(
      BoardOps.Stroke(
        ids: [name], t: nil, bounds: CGRect(x: box.minX + 58, y: y - 2, width: 104, height: 4), points: points, pen: 4)
    )
    return name
  }

  func testSeededFoldsOpenAsTheAppOpensThem() throws {
    var (opened, ended) = (0, 0)
    for seed in UInt64(1)...60 {
      var board = try WebBoard.seeded(seed)
      let folded = board.headers.map(\.id).filter { board.fold($0) }
      for id in folded {
        XCTAssertTrue(sameJSON(try asked(board, id), expected(board, id)), "\(board.name) \(id)")
        var written = board
        guard let name = writeUnder(&written, id) else { continue }
        let got = try asked(written, id)
        XCTAssertTrue(sameJSON(got, expected(written, id)), "\(board.name) \(id) written under: \(got)")
        if got["opening"] is [String: Any] { opened += 1 }
        if ((got["opening"] as? [String: Any])?["ends"] as? [String])?.contains(name) == true { ended += 1 }
      }
      for header in board.headers where !folded.contains(header.id) {
        XCTAssertTrue(sameJSON(try asked(board, header.id), ["opening": NSNull()]), "\(board.name) \(header.id)")
      }
    }
    XCTAssertGreaterThan(opened, 10, "folds opened")
    XCTAssertGreaterThan(ended, 5, "and ink written under them ends their sections")
  }
}
