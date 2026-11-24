import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Story 1294 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 19): `bw_mark_anchor`,
/// `bw_mark_place`, `bw_mark_wrote` and `bw_mark_drops` answer what the app's own `BoardMarkHolds` decides, on the
/// Cockpit's recorded boards and on seeded ones, folded and with ink erased.
final class WebMarksTests: XCTestCase {
  private func boards() throws -> [WebBoard] {
    try WebBoard.recorded() + (UInt64(1)...30).map { try WebBoard.seeded($0) }
  }

  /// The app's ink for the rule, as the board model hands it over.
  private func appInk(_ board: WebBoard) -> BoardMarkHolds.Ink {
    BoardMarkHolds.Ink(strokes: board.strokes, texts: board.texts, groups: board.groups, folds: board.app.tags)
  }

  /// The app's anchor under the names the web board knows its strokes by.
  private func webNamed(_ anchor: BoardMarkAnchor) -> BoardMarkAnchor {
    var out = anchor
    out.strokes = anchor.strokes.map {
      BoardMarkAnchor.Held(name: WebBoard.webName($0.name), x: $0.x, y: $0.y)
    }
    out.writtenBy = anchor.writtenBy.map(WebBoard.webName)
    return out
  }

  /// A mark of Larry's somewhere over or near the board's ink: a short label, or a drawn ring or underline.
  private func mark(_ id: String, _ rng: inout Seeded, over board: WebBoard) -> BoardMark {
    let shown = board.strokes.filter { !$0.hidden }
    let near = shown.isEmpty ? CGRect(x: 100, y: 100, width: 100, height: 40) : shown[rng.int(0...(shown.count - 1))].bounds
    let x = near.minX + CGFloat(rng.int(-60...80))
    let y = near.minY + CGFloat(rng.int(-50...60))
    let label = rng.int(0...2) == 0
    let w = CGFloat(rng.int(20...140))
    let h = CGFloat(rng.int(10...40))
    let lines: [[CGPoint]] =
      label
      ? [[CGPoint(x: x, y: y), CGPoint(x: x + w, y: y + h)]]
      : [(0...8).map { i in
        let a = Double(i) / 8 * 2 * .pi
        return CGPoint(x: x + w / 2 + w / 2 * CGFloat(cos(a)), y: y + h / 2 + h / 2 * CGFloat(sin(a)))
      }]
    return BoardMark(id: id, lines: lines, pen: CGFloat(rng.int(1...4)), label: label)
  }

  private func wire(_ mark: BoardMark) -> [String: Any] {
    [
      "id": mark.id, "lines": mark.lines.map { $0.map { [Double($0.x), Double($0.y)] } }, "pen": Double(mark.pen),
      "label": mark.label,
    ]
  }

  /// What the web board should be sent, written out here rather than through the module's own wire.
  private func expected(_ anchor: BoardMarkAnchor) -> [String: Any] {
    [
      "strokes": anchor.strokes.map { ["name": $0.name, "x": $0.x, "y": $0.y] as [String: Any] }, "gap": anchor.gap,
      "written_by": anchor.writtenBy,
    ]
  }

  private func expected(_ place: BoardMarkHolds.Place) -> [String: Any] {
    var drops: Any = NSNull()
    if place.hidden == .erased {
      drops = "ink_erased"
    } else if place.faded && place.hidden == nil {
      drops = "written_over"
    }
    var hidden: Any = NSNull()
    if let why = place.hidden { hidden = why == .folded ? "folded" : "erased" }
    return ["dx": Double(place.dx), "dy": Double(place.dy), "hidden": hidden, "faded": place.faded, "drops": drops]
  }

  private func json(_ object: Any) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: object))
  }

  func testAMarkHoldsToTheInkTheAppsMarkHoldsTo() throws {
    var (held, none) = (0, 0)
    for (i, board) in try boards().enumerated() {
      var rng = Seeded(UInt64(i + 7))
      let web = try board.web()
      for n in 0..<12 {
        let mark = mark("m\(n)", &rng, over: board)
        let want = webNamed(BoardMarkHolds.anchor(mark, on: appInk(board)))
        let readBack = try XCTUnwrap(WebMarks.mark(json(wire(mark))), board.name)
        let got = WebMarks.anchor(readBack, outline: web.outline, texts: web.texts, groups: web.groups)
        XCTAssert(
          sameJSONToAMillionth(got, ["anchor": expected(want)]), "\(board.name) \(mark.id): \(got) vs \(want)")
        if want.strokes.isEmpty { none += 1 } else { held += 1 }
      }
    }
    XCTAssertGreaterThan(held, 100)
    XCTAssertGreaterThan(none, 0)
  }

  func testAMarkMovesHidesAndDropsAsTheAppsDoes() throws {
    var (moved, folded, erased) = (0, 0, 0)
    for (i, start) in try boards().enumerated() {
      var rng = Seeded(UInt64(i + 101))
      var board = start
      let marks = (0..<8).map { mark("m\($0)", &rng, over: board) }
      let appAnchors = marks.map { BoardMarkHolds.anchor($0, on: appInk(board)) }
      let first = try board.web()
      let webAnchors = marks.map {
        WebMarks.anchor(WebMarks.anchor($0, outline: first.outline, texts: first.texts, groups: first.groups)["anchor"])
      }
      // The ink changes: a header folds, or a few strokes go.
      if let header = board.headers.first, board.fold(header.id) {
        folded += 1
      } else if !board.strokes.isEmpty {
        for _ in 0..<rng.int(1...4) where !board.strokes.isEmpty {
          board.strokes.remove(at: rng.int(0...(board.strokes.count - 1)))
        }
        erased += 1
      }
      let web = try board.web()
      let asked = try json(["marks": zip(marks, webAnchors).map { ["id": $0.id, "anchor": $1.map(WebMarks.wire) as Any] }])
      let held = try XCTUnwrap(WebMarks.held((asked as? [String: Any])?["marks"], needLines: false), board.name)
      let places = WebMarks.places(held, outline: web.outline)["places"] as? [String: Any] ?? [:]
      for (mark, anchor) in zip(marks, appAnchors) {
        let want = BoardMarkHolds.place(anchor, on: board.strokes)
        XCTAssert(
          sameJSONToAMillionth(places[mark.id] as Any, expected(want)),
          "\(board.name) \(mark.id): \(places[mark.id] ?? "none") vs \(want)")
        if want.dx != 0 || want.dy != 0 { moved += 1 }
      }
      let drops = WebMarks.drops(held, outline: web.outline)["drops"] as? [[String: Any]] ?? []
      let wantDrops = BoardMarkHolds.drops(
        marks, anchors: Dictionary(uniqueKeysWithValues: zip(marks.map(\.id), appAnchors)), strokes: board.strokes)
      XCTAssert(sameJSON(drops, wantDrops.map { ["id": $0.id, "why": $0.why == .writtenOver ? "written_over" : "ink_erased"] }), "\(board.name): \(drops) vs \(wantDrops)")
    }
    XCTAssertGreaterThan(moved, 0)
    XCTAssertGreaterThan(folded, 0)
    XCTAssertGreaterThan(erased, 0)
  }

  func testIgorsStrokeWritesOverTheMarksTheAppsDoes() throws {
    var over = 0
    for (i, board) in try boards().enumerated() {
      var rng = Seeded(UInt64(i + 501))
      let web = try board.web()
      let marks = (0..<6).map { mark("m\($0)", &rng, over: board) }
      var appAnchors: [String: BoardMarkAnchor] = [:]
      var webMarks: [(mark: BoardMark, anchor: BoardMarkAnchor?)] = []
      for mark in marks {
        appAnchors[mark.id] = BoardMarkHolds.anchor(mark, on: appInk(board))
        webMarks.append(
          (mark, WebMarks.anchor(WebMarks.anchor(mark, outline: web.outline, texts: web.texts, groups: web.groups)["anchor"])))
      }
      for n in 0..<6 {
        // A stroke across one of the marks, or beside it.
        let target = marks[rng.int(0...(marks.count - 1))].box
        let dy = CGFloat(rng.int(0...2) == 0 ? rng.int(30...90) : 0)
        let points = (0...10).map { k in
          [Double(target.minX + target.width * CGFloat(k) / 10), Double(target.midY + dy + CGFloat(k % 2 * 4))]
        }
        let raw = try json(["id": "igor\(n)", "points": points, "width": 3])
        let stroke = try WebOutline.ink(raw, 0)
        let before = appAnchors
        let want = BoardMarkHolds.wrote(stroke, marks: marks, anchors: &appAnchors, strokes: board.strokes)
        let got = WebMarks.wrote(stroke, marks: webMarks, outline: web.outline)
        XCTAssert(
          sameJSON(got["wrote"] as Any, want.map { ["id": $0.id, "share": ($0.share * 100).rounded() / 100] }),
          "\(board.name): \(got) vs \(want)")
        var changed: [String: Any] = [:]
        for (id, anchor) in appAnchors where before[id] != anchor { changed[id] = expected(webNamed(anchor)) }
        XCTAssert(sameJSONToAMillionth(got["anchors"] as Any, changed), "\(board.name): \(got) vs \(changed)")
        // The host keeps what changed, as the app does.
        for (id, anchor) in got["anchors"] as? [String: Any] ?? [:] {
          if let index = webMarks.firstIndex(where: { $0.mark.id == id }) {
            webMarks[index].anchor = WebMarks.anchor(anchor)
          }
        }
        over += want.count
      }
    }
    XCTAssertGreaterThan(over, 20)
  }

  func testWhatItCantReadSaysSo() throws {
    XCTAssertNil(WebMarks.mark(["id": "m"]))
    XCTAssertNil(WebMarks.mark(["id": "m", "lines": [[["x", 1]]]]))
    XCTAssertNil(WebMarks.anchor(["strokes": [["name": "a"]]]))
    XCTAssertNil(WebMarks.held([["id": "m", "anchor": "nope"]], needLines: false))
    XCTAssertNil(WebMarks.held([["id": "m"]], needLines: true))
    XCTAssertEqual(WebMarks.held([["id": "m"]], needLines: false)?.count, 1)
  }
}
