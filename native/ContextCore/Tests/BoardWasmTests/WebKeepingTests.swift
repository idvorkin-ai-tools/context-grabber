import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Story 1163 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 14): `bw_keep_all` and `bw_tidy`
/// answer what the app's own Keep all and Tidy overlaps decide, on the Cockpit's recorded boards and on seeded ones.
final class WebKeepingTests: XCTestCase {
  /// A board as the iPad posts it, read both ways: the app's strokes with each one's time (as its Keep all reads
  /// them), and the web board's outline (ink with its points and time, each kept text as its box) through the module.
  private struct Timed {
    var name: String
    var snapshot: BoardSnapshot
    var app: (strokes: [BoardOps.Stroke], texts: [BoardText], groups: [String: String])
    var web: (outline: BoardOutline, texts: [BoardText], groups: [String: String])

    init(name: String, snapshot: BoardSnapshot) throws {
      self.name = name
      self.snapshot = snapshot
      let input = snapshot.planInput
      var strokes = input.strokes
      for i in snapshot.ink.indices { strokes[i].t = snapshot.ink[i].t }
      app = (strokes, input.texts, input.metas.groups)
      var groups: [String: String] = [:]
      let ink = snapshot.ink.map { ink -> [String: Any] in
        if let group = ink.meta?.group { groups[ink.id] = group }
        var wire: [String: Any] = [
          "id": ink.id, "points": ink.points.map { [Double($0.x), Double($0.y)] }, "width": Double(ink.width),
          "hidden": ink.hidden,
        ]
        if let t = ink.t { wire["t"] = t }
        return wire
      }
      let boxes = snapshot.texts.map { text -> [String: Any] in
        let b = text.box
        return ["id": text.id, "box": [Double(b.minX), Double(b.minY), Double(b.maxX), Double(b.maxY)]]
      }
      let wire: [String: Any] = ["strokes": ink, "boxes": boxes, "groups": groups, "headers": [Any]()]
      web = try WebOutline.parts(json: JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: wire)))
    }

    /// The times of the ink, earliest first, and the page's extent.
    var times: [Int64] { snapshot.ink.compactMap(\.t).sorted() }
    var extent: CGRect {
      (snapshot.ink.map(\.bounds) + snapshot.texts.map(\.box)).reduce(CGRect.null) { $0.union($1) }
    }
  }

  private func recorded() throws -> [Timed] {
    try WebBoard.recorded().map { board in
      let text = try String(
        contentsOf: WebBoard.fixtures.appendingPathComponent("\(board.name).jsonl"), encoding: .utf8)
      var last: Any?
      for line in text.split(separator: "\n") {
        guard let step = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          step["step"] as? String == "post", step["route"] as? String == "/whiteboard/strokes"
        else { continue }
        last = step["body"]
      }
      return try Timed(name: board.name, snapshot: BoardSnapshot(json: XCTUnwrap(last)))
    }
  }

  /// A seeded board of lines of short strokes, each made a second after the one before, some lines grouped as one of
  /// Larry's replies, a kept text now and then. Whole points throughout.
  private func seeded(_ seed: UInt64) throws -> Timed {
    var rng = Seeded(seed)
    var strokes: [[String: Any]] = []
    var y = 100
    var t: Int64 = 1_000_000
    for line in 0..<rng.int(6...14) {
      let x = rng.int(0...3) * 40 + 60
      if rng.int(0...7) == 0 {
        strokes.append(["id": "t\(line)", "kind": "text", "x": x, "y": y, "w": 160, "h": 40, "t": t])
        t += 1000
        y += 40 + rng.int(10...40)
        continue
      }
      let h = rng.int(16...40)
      let group = rng.int(0...5) == 0 ? "reply-r\(line)" : nil
      for i in 0..<rng.int(2...6) {
        let left = x + i * rng.int(20...44)
        var stroke: [String: Any] = [
          "id": "l\(line)s\(i)", "points": [[left, y + h], [left + 10, y], [left + 20, y + h]], "width": 3, "t": t,
        ]
        if let group { stroke["meta"] = ["group": group] }
        strokes.append(stroke)
        t += 1000
      }
      y += h + rng.int(8...44)
    }
    return try Timed(name: "seeded \(seed)", snapshot: BoardSnapshot(json: ["board": "seeded", "strokes": strokes]))
  }

  // MARK: - Keep all

  /// Seeded marks over the board: a few replies, each with one to three marks, its picture taken at one of the ink's
  /// times (or unknown), and a text of Larry's landing now and then.
  private func keepings(_ board: Timed, _ rng: inout Seeded) -> [(marks: [WebKeeping.Mark], landing: [CGRect])] {
    let extent = board.extent.isNull ? CGRect(x: 0, y: 0, width: 800, height: 800) : board.extent
    let times = board.times
    func box() -> CGRect {
      let x = CGFloat(rng.int(0...max(1, Int(extent.width)))) + extent.minX - 40
      let y = CGFloat(rng.int(0...max(1, Int(extent.height)))) + extent.minY - 40
      return CGRect(x: x, y: y, width: CGFloat(rng.int(20...240)), height: CGFloat(rng.int(10...120)))
    }
    return (0..<24).map { _ in
      var marks: [WebKeeping.Mark] = []
      for reply in 0..<rng.int(1...3) {
        let seen: Int64? = times.isEmpty || rng.int(0...4) == 0 ? nil : times[rng.int(0...(times.count - 1))]
        for i in 0..<rng.int(1...3) {
          marks.append(WebKeeping.Mark(id: WhiteboardMarks.mark(i, of: "r\(reply)"), box: box(), seen: seen))
        }
      }
      if rng.int(0...5) == 0 { marks.append(WebKeeping.Mark(id: "text-1", box: box(), seen: nil)) }
      return (marks, rng.int(0...3) == 0 ? [box()] : [])
    }
  }

  /// The app's Keep all, as its replay keeps: groups by reply, and the one room over its strokes with their times.
  /// A kept text on the board is Larry's or Claude's, so its time is among theirs, as when the app kept it.
  private func expected(
    _ board: Timed, _ marks: [WebKeeping.Mark], landing: [CGRect], theirs: Set<Int64>
  ) -> [String: Any] {
    let groups = WhiteboardMarks.keptGroups(marks.map(\.id)).mapValues(WhiteboardMarks.group(reply:))
    let late = BoardRoom.late(
      marks.map { (box: $0.box, seen: $0.seen) }, landing: landing, strokes: board.app.strokes,
      texts: board.app.texts, groups: board.app.groups, theirs: theirs.union(board.app.texts.map(\.t)))
    let push: Any = late.push.map { ["cut": Double($0.cut), "dy": Double($0.dy)] } ?? NSNull()
    return ["groups": groups, "push": push, "covered": late.covered]
  }

  private func checkKeepAll(_ board: Timed, seed: UInt64) -> (asked: Int, pushed: Int) {
    var rng = Seeded(seed)
    var pushed = 0
    let all = keepings(board, &rng)
    for (marks, landing) in all {
      let theirs: Set<Int64> = board.times.isEmpty || rng.int(0...2) > 0 ? [] : [board.times[0]]
      let want = expected(board, marks, landing: landing, theirs: theirs)
      let got = WebKeeping.keepAll(
        board.web.outline, texts: board.web.texts, groups: board.web.groups, marks: marks, landing: landing,
        theirs: theirs)
      XCTAssertEqual(NSDictionary(dictionary: got), NSDictionary(dictionary: want), "\(board.name): \(marks)")
      if !(got["push"] is NSNull) { pushed += 1 }
    }
    return (all.count, pushed)
  }

  func testKeepAllOnTheRecordedBoardsIsTheAppsKeepAll() throws {
    var pushed = 0
    for (i, board) in try recorded().enumerated() { pushed += checkKeepAll(board, seed: UInt64(i + 1)).pushed }
    XCTAssertGreaterThan(pushed, 3, "some of the recorded keeps open room")
  }

  func testKeepAllOnSeededBoardsIsTheAppsKeepAll() throws {
    var (asked, pushed) = (0, 0)
    for seed in UInt64(1)...40 {
      let result = checkKeepAll(try seeded(seed), seed: seed &* 7)
      asked += result.asked
      pushed += result.pushed
    }
    XCTAssertGreaterThan(pushed, asked / 10, "a good share of the seeded keeps open room: \(pushed) of \(asked)")
  }

  func testAReplyOfTwoMarksIsOneGroupAndALoneMarkIsNone() throws {
    let board = try seeded(3)
    let marks = [
      WebKeeping.Mark(id: "a#0", box: CGRect(x: 0, y: 0, width: 10, height: 10), seen: nil),
      WebKeeping.Mark(id: "a#1", box: CGRect(x: 0, y: 20, width: 10, height: 10), seen: nil),
      WebKeeping.Mark(id: "b#0", box: CGRect(x: 0, y: 40, width: 10, height: 10), seen: nil),
    ]
    let got = WebKeeping.keepAll(
      board.web.outline, texts: board.web.texts, groups: board.web.groups, marks: marks, landing: [], theirs: [])
    XCTAssertEqual(got["groups"] as? [String: String], ["a#0": "reply-a", "a#1": "reply-a"])
    XCTAssertTrue(got["push"] is NSNull, "no picture time and no text: no room")
  }

  // MARK: - Tidy

  /// The app's Tidy overlaps: labels picked out by their moments (`WhiteboardTidy.laid`), then laid out over the ink's
  /// points. Here each label is one stroke given a moment of its own, so the app's label is the web's by that stroke.
  private func checkTidy(_ board: Timed, seed: UInt64) -> Int {
    var rng = Seeded(seed)
    var moved = 0
    let ink = board.app.strokes.indices.filter { !board.app.strokes[$0].points.isEmpty }
    for _ in 0..<8 where !ink.isEmpty {
      var strokes = board.app.strokes.filter { !$0.points.isEmpty }
      for i in strokes.indices { strokes[i].t = nil }
      let chosen = Set((0..<rng.int(1...4)).map { _ in rng.int(0...(strokes.count - 1)) })
      var known: Set<Int64> = []
      for i in chosen {
        strokes[i].t = Int64(5_000 + i)
        known.insert(Int64(5_000 + i))
      }
      let laid = WhiteboardTidy.laid(strokes, known: known, groups: board.app.groups)
      let labels = laid.labels.mapValues { $0.map { strokes[$0].points } }
      let appMoves = WhiteboardTidy.tidy(labels, among: laid.ink.map { strokes[$0].points })
      var want: [String: Double] = [:]
      for (key, dy) in appMoves {
        if let i = laid.labels[key]?.first { want[strokes[i].ids[0]] = Double(dy) }
      }
      // The web board's outline of the same ink, its kept texts left out (the app's are glyphs, the web's boxes).
      let wire: [String: Any] = [
        "strokes": strokes.map { s in
          ["id": s.ids[0], "points": s.points.map { [Double($0.x), Double($0.y)] }, "width": Double(s.pen)]
        },
        "groups": board.app.groups,
      ]
      guard let json = try? JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: wire)),
        let web = try? WebOutline.parts(json: json)
      else {
        XCTFail("\(board.name): the outline could not be read")
        return moved
      }
      let got = WebKeeping.tidy(web.outline, groups: web.groups, labels: chosen.map { strokes[$0].ids[0] })
      XCTAssertEqual(got["moves"] as? [String: Double], want, "\(board.name): labels \(chosen.sorted())")
      moved += want.count
    }
    return moved
  }

  func testTidyOnTheRecordedBoardsIsTheAppsTidy() throws {
    var moved = 0
    for (i, board) in try recorded().enumerated() { moved += checkTidy(board, seed: UInt64(i + 11)) }
    XCTAssertGreaterThan(moved, 2, "some recorded labels sit on ink and move")
  }

  func testTidyOnSeededBoardsIsTheAppsTidy() throws {
    var moved = 0
    for seed in UInt64(1)...40 { moved += checkTidy(try seeded(seed), seed: seed) }
    XCTAssertGreaterThan(moved, 20, "seeded labels sit on ink and move")
  }

  func testAKeptTextIsInkOverItsWholeBoxAndAHiddenStrokeIsNone() throws {
    // A label (a zigzag across 190..210) inside a kept text's box (180..240) moves under it, 20 below its bottom (to
    // 260, 70 down); a hidden stroke where it lands is no ink.
    let wire: [String: Any] = [
      "strokes": [
        ["id": "l", "points": [[50, 190], [70, 210], [90, 190]], "width": 2],
        ["id": "h", "points": [[40, 262], [100, 262]], "width": 2, "hidden": true],
      ],
      "boxes": [["id": "k", "box": [0, 180, 300, 240]]],
    ]
    let web = try WebOutline.parts(
      json: JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: wire)))
    let got = WebKeeping.tidy(web.outline, groups: web.groups, labels: ["l"])
    XCTAssertEqual(got["moves"] as? [String: Double], ["l": 70])
  }
}
