import XCTest

@testable import BoardCore
@testable import BoardWasm

/// Story 1265 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 12): `bw_fold_erase` takes the
/// folds the app's own outline takes and erases them as it does, on seeded boards folded.
final class WebFoldEraseTests: XCTestCase {
  /// The app's answer in the export's form, a kept text's glyphs named as the web board names the text.
  private func expected(_ board: WebBoard, hits: [BoardOutline.FoldHit]) -> [String: Any] {
    let app = board.app
    let n = WebBoard.webName
    let listed: [[String: Any]] = hits.map { hit in
      [
        "header": hit.header, "byMarker": hit.byMarker, "headers": hit.headers.sorted(),
        "names": hit.names.map(n).sorted(), "top": Double(hit.top),
      ]
    }
    var copy = app
    guard copy.eraseFolds(hits) else { return ["hits": listed, "erased": NSNull()] }
    var moves: [String: Double] = [:]
    for (i, (was, now)) in zip(app.strokes, copy.strokes).enumerated() where !copy.erased.contains(i) {
      let dy = now.bounds.minY - was.bounds.minY
      if dy != 0 { for name in now.ids { moves[n(name)] = Double(dy) } }
    }
    let gone = Set(app.headers.map(\.id)).subtracting(copy.headers.map(\.id))
    return [
      "hits": listed,
      "erased": [
        "names": copy.erased.sorted().flatMap { copy.strokes[$0].ids }.map(n), "headers": gone.sorted(),
        "moves": moves,
      ] as [String: Any],
    ]
  }

  private func asked(_ board: WebBoard, path: [CGPoint]?, onHeader: Bool = false, headers: [String] = [])
    throws -> [String: Any]
  {
    WebFoldErase.erase(
      try board.web().outline, path: path, reach: BoardOutline.eraseReach, onHeader: onHeader, headers: headers)
  }

  func testSeededFoldsAreErasedAsTheAppErasesThem() throws {
    var (byMarker, byWords, byName, sameAsMarker) = (0, 0, 0, 0)
    for seed in UInt64(1)...60 {
      var board = try WebBoard.seeded(seed)
      for header in board.headers { _ = board.fold(header.id) }
      let app = board.app
      for marker in app.markers {
        let across = [
          CGPoint(x: marker.box.midX - 5, y: marker.box.midY), CGPoint(x: marker.box.midX + 5, y: marker.box.midY),
        ]
        let want = expected(board, hits: app.foldHits(along: across, onHeader: false))
        let got = try asked(board, path: across)
        XCTAssertTrue(sameJSON(got, want), "\(board.name) \(marker.header) by its marker: \(got)")
        if !(got["hits"] as? [Any] ?? []).isEmpty { byMarker += 1 }
        let named = try asked(board, path: nil, headers: [marker.header])
        let wantNamed = expected(board, hits: [try XCTUnwrap(app.foldHit(marker.header))])
        XCTAssertTrue(sameJSON(named, wantNamed), "\(board.name) \(marker.header) by name: \(named)")
        if named["erased"] is [String: Any] { byName += 1 }
        if let hits = got["hits"] as? [[String: Any]], hits.count == 1, hits[0]["header"] as? String == marker.header {
          XCTAssertTrue(sameJSON(named, got), "\(board.name) \(marker.header) by name as by its marker: \(named)")
          sameAsMarker += 1
        }
        // Across its first word's stroke: only with onHeader.
        guard let word = app.header(marker.header)?.words.first,
          let stroke = app.strokes.first(where: { $0.ids.contains(word) }), let p = stroke.points.first
        else { continue }
        for onHeader in [false, true] {
          let path = [p, CGPoint(x: p.x + 1, y: p.y)]
          let got = try asked(board, path: path, onHeader: onHeader)
          XCTAssertTrue(
            sameJSON(got, expected(board, hits: app.foldHits(along: path, onHeader: onHeader))),
            "\(board.name) \(marker.header) across its words, onHeader \(onHeader): \(got)")
          if onHeader, !(got["hits"] as? [Any] ?? []).isEmpty { byWords += 1 }
        }
      }
      let clear = [CGPoint(x: 900, y: 5), CGPoint(x: 910, y: 5)]
      XCTAssertTrue(sameJSON(try asked(board, path: clear), ["hits": [Any](), "erased": NSNull()]), board.name)
    }
    XCTAssertGreaterThan(byMarker, 10, "folds taken by their marker")
    XCTAssertGreaterThan(byWords, 10, "and by their header's words")
    XCTAssertEqual(byName, byMarker, "and by name, each one")
    XCTAssertGreaterThan(sameAsMarker, 10, "by name exactly as by its marker")
  }
}
