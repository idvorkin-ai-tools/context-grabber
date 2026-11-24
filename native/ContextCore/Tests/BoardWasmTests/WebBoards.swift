import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// A board twice over: as the app's own outline holds it, and as the Cockpit's web board sends it (`bw_outline_load`'s
/// outline: ink with its points, each kept text as its box). The host tests ask both and compare.
struct WebBoard {
  var name: String
  var strokes: [BoardOps.Stroke]
  var texts: [BoardText]
  var groups: [String: String]
  var headers: [BoardHeader] = []

  /// A board as the iPad posts it, through the app's own reading of it.
  init(name: String, snapshot: BoardSnapshot) {
    self.name = name
    let input = snapshot.planInput
    strokes = input.strokes
    texts = input.texts
    groups = input.metas.groups
  }

  /// The app's outline of it.
  var app: BoardOutline { BoardOutline(strokes: strokes, headers: headers, texts: texts, groups: groups) }

  /// The name the web board gives a stroke of the app's: a kept text's glyphs go by the text's id.
  static func webName(_ name: String) -> String {
    name.hasSuffix("#glyphs") ? String(name.dropLast("#glyphs".count)) : name
  }

  /// The outline as the web board sends it, read back through JSON as the module reads it.
  var webJSON: Any {
    var ink: [[String: Any]] = []
    var boxes: [[String: Any]] = []
    for s in strokes {
      if s.points.isEmpty {
        let b = s.bounds
        boxes.append([
          "id": Self.webName(s.ids[0]), "box": [Double(b.minX), Double(b.minY), Double(b.maxX), Double(b.maxY)],
          "hidden": s.hidden,
        ])
      } else {
        ink.append([
          "id": s.ids[0], "points": s.points.map { [Double($0.x), Double($0.y)] }, "width": Double(s.pen),
          "hidden": s.hidden,
        ])
      }
    }
    // A text the app groups by its glyphs' time is grouped by its own name on the web.
    let renamed = self.headers.map { h -> BoardHeader in
      var h = h
      h.ids = h.ids.map(Self.webName)
      if var fold = h.fold {
        fold.ids = fold.ids.map(Self.webName)
        fold.own = fold.own.map(Self.webName)
        h.fold = fold
      }
      h.ends = h.ends?.map(Self.webName)
      return h
    }
    let headers = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(renamed))) ?? []
    let wire: [String: Any] = ["strokes": ink, "boxes": boxes, "groups": groups, "headers": headers]
    // swiftlint:disable:next force_try
    return try! JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: wire))
  }

  /// The web board's outline, read by the module's own reading.
  func web() throws -> (outline: BoardOutline, texts: [BoardText], groups: [String: String]) {
    try WebOutline.parts(json: webJSON)
  }

  /// The board with header `id` folded by the app's own fold, as both sides would then hold it.
  mutating func fold(_ id: String) -> Bool {
    var o = app
    guard o.fold(id) else { return false }
    strokes = o.strokes
    headers = o.headers
    return true
  }

  // MARK: - Recorded and seeded boards

  static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../ContextCoreTests/Fixtures/board-sessions").standardized

  /// The last board each of the Cockpit's recorded sessions posted.
  static func recorded() throws -> [WebBoard] {
    let names = ["ops-move", "plain-draw", "question-card", "title-build"]
    return try names.map { name in
      let text = try String(contentsOf: fixtures.appendingPathComponent("\(name).jsonl"), encoding: .utf8)
      var last: Any?
      for line in text.split(separator: "\n") {
        guard let step = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          step["step"] as? String == "post", step["route"] as? String == "/whiteboard/strokes"
        else { continue }
        last = step["body"]
      }
      let body = try XCTUnwrap(last, "\(name) posted no board")
      return WebBoard(name: name, snapshot: try BoardSnapshot(json: body))
    }
  }

  /// A seeded board of lines of writing: usual lines, some big, some underlined, some indented under the line before,
  /// a kept text and a group of Larry's now and then, and a header on some lines. Whole points throughout, so a fold's
  /// shift moves the app's box and the web's points alike, exactly.
  static func seeded(_ seed: UInt64) throws -> WebBoard {
    var rng = Seeded(seed)
    var strokes: [[String: Any]] = []
    var lines: [(names: [String], ink: Bool)] = []
    var y = 100
    for line in 0..<rng.int(6...14) {
      let kind = rng.int(0...9)
      let x = rng.int(0...2) == 0 ? 140 : 100
      if kind == 0 {
        strokes.append(["id": "t\(line)", "kind": "text", "x": x, "y": y, "w": 160, "h": 40, "t": 1000 + line])
        lines.append((["t\(line)"], false))
        y += 40 + rng.int(16...40)
        continue
      }
      let big = kind == 1 || kind == 2
      let h = big ? rng.int(50...70) : rng.int(20...28)
      let w = big ? 40 : 20
      var names: [String] = []
      let group = kind == 3 ? "g\(line)" : nil
      for i in 0..<rng.int(3...6) {
        let left = x + i * (w + 4)
        let id = "l\(line)s\(i)"
        var stroke: [String: Any] = [
          "id": id, "points": [[left, y + h], [left + w / 2, y], [left + w, y + h]], "width": 3,
        ]
        if let group { stroke["meta"] = ["group": group] }
        strokes.append(stroke)
        names.append(id)
      }
      if kind == 2 || kind == 4 {
        let right = x + names.count * (w + 4)
        strokes.append(["id": "u\(line)", "points": [[x - 2, y + h + 4], [right, y + h + 4]], "width": 3])
        names.append("u\(line)")
      }
      lines.append((names, group == nil))
      y += h + rng.int(12...40)
    }
    var board = WebBoard(
      name: "seeded \(seed)", snapshot: try BoardSnapshot(json: ["board": "seeded", "strokes": strokes]))
    for (i, line) in lines.enumerated() where line.ink && rng.int(0...4) == 0 {
      board.headers.append(BoardHeader(id: "H\(i)", ids: line.names))
    }
    return board
  }
}

/// The same JSON, keys sorted: what the module would send for each (NSDictionary's equality differs on Linux).
func sameJSON(_ a: Any, _ b: Any) -> Bool {
  let data = { (x: Any) in try? JSONSerialization.data(withJSONObject: x, options: [.sortedKeys]) }
  return data(a) != nil && data(a) == data(b)
}

/// SplitMix64: the same boards every run.
struct Seeded {
  var state: UInt64
  init(_ seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func int(_ range: ClosedRange<Int>) -> Int {
    range.lowerBound + Int(next() % UInt64(range.count))
  }
}
