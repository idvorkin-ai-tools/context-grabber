import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Story 1165 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 17): `bw_scratch_out` and
/// `bw_shape_snap` answer what the app's own scratch-out and shape snap decide, on the Cockpit's recorded boards and on
/// seeded zigzags and strokes.
final class WebScratchTests: XCTestCase {
  private func json(_ object: Any) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: object))
  }

  /// The board's ink as the web board sends it, and as the app's scratch-out takes it from the iPad's strokes.
  private func boards() throws -> [(name: String, web: BoardOutline, app: [WhiteboardScratchOut.Ink])] {
    var out: [(String, BoardOutline, [WhiteboardScratchOut.Ink])] = []
    var snapshots: [(String, BoardSnapshot)] = []
    for name in ["ops-move", "plain-draw", "question-card", "title-build"] {
      let text = try String(contentsOf: WebBoard.fixtures.appendingPathComponent("\(name).jsonl"), encoding: .utf8)
      var last: Any?
      for line in text.split(separator: "\n") {
        guard let step = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          step["step"] as? String == "post", step["route"] as? String == "/whiteboard/strokes"
        else { continue }
        last = step["body"]
      }
      snapshots.append((name, try BoardSnapshot(json: XCTUnwrap(last))))
    }
    for seed in UInt64(1)...20 {
      var rng = Seeded(seed)
      var strokes: [[String: Any]] = []
      for i in 0..<rng.int(10...40) {
        let (x, y) = (rng.int(0...700), rng.int(0...900))
        let points = (0..<rng.int(2...8)).map { _ in [x + rng.int(0...60), y + rng.int(0...30)] }
        strokes.append(["id": "s\(i)", "points": points, "width": rng.int(1...6)])
      }
      snapshots.append(("seeded \(seed)", try BoardSnapshot(json: ["board": "seeded", "strokes": strokes])))
    }
    for (name, snapshot) in snapshots {
      let shown = snapshot.ink.filter { !$0.hidden }
      let wire: [String: Any] = [
        "strokes": snapshot.ink.map { ink in
          [
            "id": ink.id, "points": ink.points.map { [Double($0.x), Double($0.y)] }, "width": Double(ink.width),
            "hidden": ink.hidden,
          ] as [String: Any]
        }
      ]
      let web = try WebOutline.parts(json: json(wire)).outline
      out.append((name, web, shown.map { WhiteboardScratchOut.Ink(id: $0.id, points: $0.points, width: $0.width) }))
    }
    return out
  }

  func testAZigzagScratchesOutWhatTheAppsScratchOutTakes() throws {
    var (taken, refused) = (0, 0)
    for (i, board) in try boards().enumerated() {
      var rng = Seeded(UInt64(i + 1))
      for _ in 0..<30 where !board.app.isEmpty {
        // Over a stroke or two of the board, beside them, or slow; a wobble now and then.
        let target = board.app[rng.int(0...(board.app.count - 1))].points
        var box = target.dropFirst().reduce(CGRect(origin: target[0], size: .zero)) {
          $0.union(CGRect(origin: $1, size: .zero))
        }
        box = box.insetBy(dx: -CGFloat(rng.int(0...20)), dy: -CGFloat(rng.int(0...10)))
        if rng.int(0...4) == 0 { box = box.offsetBy(dx: CGFloat(rng.int(-80...80)), dy: CGFloat(rng.int(-40...40))) }
        var (points, ms) = WhiteboardScratchOut.zigzag(across: box)
        if rng.int(0...3) == 0 { ms *= Double(rng.int(2...20)) }
        if rng.int(0...5) == 0 { points = points.map { CGPoint(x: $0.x, y: $0.y + CGFloat(rng.int(-6...6))) } }
        let timed: Double? = rng.int(0...5) == 0 ? nil : ms
        let want = WhiteboardScratchOut.check(points, ms: timed, over: board.app)
        let got = WebScratch.scratchOut(board.web, points: points, ms: timed)
        XCTAssertEqual(got["ok"] as? Bool, want.ok, board.name)
        XCTAssertEqual(got["gone"] as? [String], want.gone, board.name)
        XCTAssertEqual(got["reversals"] as? Int, want.reversals, board.name)
        XCTAssertEqual(got["speed"] as? Double, want.speed, board.name)
        XCTAssertEqual(got["why"] as? String, want.why, board.name)
        XCTAssertEqual(got["finds_nothing"] as? Bool, want.findsNothing, board.name)
        XCTAssertEqual(got["zigzag"] as? Bool, WhiteboardScratchOut.isZigzag(points, ms: timed), board.name)
        if want.ok { taken += 1 } else { refused += 1 }
      }
    }
    XCTAssertGreaterThan(taken, 50, "zigzags scratch out")
    XCTAssertGreaterThan(refused, 50, "and some stay ink")
  }

  /// Seeded strokes: rough lines, boxes and rings, scribbles; each with times, held at the end or not.
  func testAStrokeSnapsAndIsHeldAsTheAppsSnap() throws {
    var kinds: [String: Int] = [:]
    var held = 0
    for seed in UInt64(1)...200 {
      var rng = Seeded(seed)
      let (cx, cy) = (CGFloat(rng.int(100...500)), CGFloat(rng.int(100...500)))
      let (w, h) = (CGFloat(rng.int(10...200)), CGFloat(rng.int(10...160)))
      let wobble = { CGFloat(rng.int(-3...3)) }
      var points: [CGPoint]
      switch rng.int(0...3) {
      case 0:
        points = (0...20).map { k in
          CGPoint(x: cx + w * CGFloat(k) / 20 + wobble(), y: cy + h * CGFloat(k) / 60 + wobble())
        }
      case 1:
        let corners = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)].map {
          CGPoint(x: cx + w * CGFloat($0.0), y: cy + h * CGFloat($0.1))
        }
        points = zip(corners, corners.dropFirst()).flatMap { a, b in
          (0..<8).map { k in
            CGPoint(x: a.x + (b.x - a.x) * CGFloat(k) / 8 + wobble(), y: a.y + (b.y - a.y) * CGFloat(k) / 8 + wobble())
          }
        }
      case 2:
        points = (0...36).map { k in
          let t = CGFloat(k) / 36 * 2 * .pi
          return CGPoint(x: cx + w / 2 * cos(t) + wobble(), y: cy + h / 2 * sin(t) + wobble())
        }
      default:
        points = (0..<rng.int(3...30)).map { _ in
          CGPoint(x: cx + CGFloat(rng.int(0...100)), y: cy + CGFloat(rng.int(0...100)))
        }
      }
      // A point every 20 ms, then the pen still (or not) for a while before the lift.
      var times = points.indices.map { Double($0) * 0.02 }
      let still = rng.int(0...1) == 0
      if still {
        points += Array(repeating: points[points.count - 1], count: 3)
        times += [1, 2, 3].map { times[times.count - 1] + Double($0) * 0.2 }
      }
      let lifted = (times.last ?? 0) + Double(rng.int(0...3)) * 0.1
      var hold = BoardShapeSnap.Hold()
      for (p, t) in zip(points, times) { hold.moved(to: p, at: t) }
      let wantHeld = hold.held(liftedAt: points[points.count - 1], time: lifted)
      let want = BoardShapeSnap.clean(points)
      let got = WebScratch.snap(
        try XCTUnwrap(WebScratch.points(json(points.map { [Double($0.x), Double($0.y)] }))), times: times,
        lifted: lifted)
      XCTAssertEqual(got["held"] as? Bool, wantHeld, "seed \(seed)")
      let shape = got["shape"] as? [String: Any]
      XCTAssertEqual(shape?["kind"] as? String, want?.kind.rawValue, "seed \(seed)")
      XCTAssertEqual(shape?["error"] as? Double, want?.error, "seed \(seed)")
      XCTAssertEqual(
        shape?["points"] as? [[Double]], want?.points.map { [Double($0.x), Double($0.y)] }, "seed \(seed)")
      kinds[want?.kind.rawValue ?? "none", default: 0] += 1
      if wantHeld { held += 1 }
    }
    for kind in ["line", "rect", "ellipse", "none"] { XCTAssertGreaterThan(kinds[kind] ?? 0, 10, "\(kinds)") }
    XCTAssertGreaterThan(held, 50)
    XCTAssertLessThan(held, 150)
  }

  func testWithoutTimesHeldIsUnknown() {
    let got = WebScratch.snap([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)], times: nil, lifted: nil)
    XCTAssertTrue(got["held"] is NSNull)
    XCTAssertTrue(got["shape"] is NSNull, "two points are too few to snap")
  }
}
