import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Stories 1104, 1105 (bead context-grabber-y544): a pen touch's path in the session log, and a pulled log's gestures
/// judged again on the Mac.
final class BoardTouchReplayTests: XCTestCase {
  typealias Sample = BoardTouchPath.Sample

  private static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Fixtures")

  // MARK: - The path

  func testAPathComesBackToATenthOfAPointAndAMillisecond() throws {
    let samples = [
      Sample(CGPoint(x: 490.74, y: 321.66), ms: 0), Sample(CGPoint(x: 489.71, y: 319.04), ms: 8.4),
      Sample(CGPoint(x: -3.25, y: 1_204.96), ms: 16.6), Sample(CGPoint(x: 0, y: 0), ms: 2_000.2),
    ]
    let back = try XCTUnwrap(BoardTouchPath.decode(BoardTouchPath.encode(samples)))
    XCTAssertEqual(back.count, samples.count)
    for (a, b) in zip(samples, back) {
      XCTAssertEqual(a.point.x, b.point.x, accuracy: 0.051)
      XCTAssertEqual(a.point.y, b.point.y, accuracy: 0.051)
      XCTAssertEqual(a.ms, b.ms, accuracy: 0.51)
    }
    XCTAssertEqual(BoardTouchPath.encode(samples).components(separatedBy: ";").first, "4907,3217,0")
  }

  func testALongPathNeverDriftsAndIsThinnedKeepingItsEnds() throws {
    let samples = (0..<1_500).map {
      Sample(CGPoint(x: 100 + Double($0) * 0.33, y: 50 - Double($0) * 0.07), ms: Double($0) * 8.3)
    }
    let back = try XCTUnwrap(BoardTouchPath.decode(BoardTouchPath.encode(samples)))
    XCTAssertEqual(back.count, BoardTouchPath.most)
    XCTAssertEqual(try XCTUnwrap(back.first).point.x, 100, accuracy: 0.051)
    XCTAssertEqual(try XCTUnwrap(back.last).point.x, try XCTUnwrap(samples.last).point.x, accuracy: 0.051)
    XCTAssertEqual(try XCTUnwrap(back.last).point.y, try XCTUnwrap(samples.last).point.y, accuracy: 0.051)
    XCTAssertEqual(try XCTUnwrap(back.last).ms, try XCTUnwrap(samples.last).ms, accuracy: 0.51)
  }

  func testTextTheLogDidNotWriteIsNoPath() {
    XCTAssertNil(BoardTouchPath.decode("1,2"))
    XCTAssertNil(BoardTouchPath.decode("1,2,3;x,1,1"))
    XCTAssertNil(BoardTouchPath.decode("1,2,3;"))
    XCTAssertEqual(BoardTouchPath.decode(""), [])
  }

  /// The oracle: Igor's own scratch-outs and hatching (`Fixtures/scratch-out/igor-2026-11-21.json`) judged the same after
  /// they have been through the log's path.
  func testIgorsRealScribblesAreJudgedTheSameAfterTheLog() throws {
    let url = Self.fixtures.appendingPathComponent("scratch-out/igor-2026-11-21.json")
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
    func points(_ any: Any?) -> [CGPoint] { (any as? [[Double]] ?? []).map { CGPoint(x: $0[0], y: $0[1]) } }
    for c in cases {
      let name = c["name"] as? String ?? "?"
      let raw = points(c["points"])
      let ms = c["ms"] as? Double
      let ink = (c["ink"] as? [[String: Any]] ?? []).map {
        WhiteboardScratchOut.Ink(
          id: $0["id"] as? String ?? "", points: points($0["points"]), width: CGFloat($0["width"] as? Double ?? 3))
      }
      let total = ms ?? 0
      let samples = raw.enumerated().map { i, p in
        Sample(p, ms: raw.count > 1 ? total * Double(i) / Double(raw.count - 1) : 0)
      }
      let back = try XCTUnwrap(BoardTouchPath.decode(BoardTouchPath.encode(samples)), name)
      let after = WhiteboardScratchOut.check(back.map(\.point), ms: ms == nil ? nil : back.last?.ms, over: ink)
      XCTAssertEqual(after, WhiteboardScratchOut.check(raw, ms: ms, over: ink), name)
    }
  }

  // MARK: - A log's cases

  private func line(_ type: String, _ fields: [String: Any], t: Int = 1_000) -> String {
    String(decoding: SessionLogLine.encode(type: type, t: t, fields: fields), as: UTF8.self)
  }

  private func timed(_ points: [CGPoint], ms: Double) -> [Sample] {
    points.enumerated().map { i, p in Sample(p, ms: ms * Double(i) / Double(max(points.count - 1, 1))) }
  }

  /// A rectangle drawn round and held still at its end for `hold` seconds.
  private func heldBox(hold: Double) -> [Sample] {
    let corners = [
      CGPoint(x: 200, y: 200), CGPoint(x: 320, y: 200), CGPoint(x: 320, y: 280), CGPoint(x: 200, y: 280),
      CGPoint(x: 200, y: 202),
    ]
    var samples: [Sample] = []
    for (a, b) in zip(corners, corners.dropFirst()) {
      for k in 0..<10 {
        let f = CGFloat(k) / 10
        samples.append(
          Sample(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), ms: Double(samples.count) * 16))
      }
    }
    let end = samples.count
    samples.append(Sample(corners[4], ms: Double(end) * 16))
    samples.append(Sample(CGPoint(x: 201, y: 202), ms: Double(end) * 16 + hold * 1000))
    return samples
  }

  func testALogsGesturesBecomeCasesWithWhatTheIPadAndTheMacSaid() throws {
    let zigzag = WhiteboardScratchOut.zigzag(across: CGRect(x: 100, y: 100, width: 120, height: 20))
    let margin = (0..<40).map { Sample(CGPoint(x: 20, y: 500 + Double($0) * 0.1), ms: Double($0) * 20) }
    let writing = (0..<30).map {
      Sample(CGPoint(x: 300 + Double($0) * 2, y: 400 + Double($0 % 3)), ms: Double($0) * 10)
    }
    let log = [
      line(
        "whiteboard",
        [
          "action": "scratch", "board": "b1", "fired": true, "reversals": 4, "strokes": 1,
          "path": BoardTouchPath.encode(timed(zigzag.points, ms: zigzag.ms)),
        ]),
      line(
        "board_margin",
        [
          "action": "hold_stroke", "board": "b1", "verdict": "hold", "tool": "pencil",
          "path": BoardTouchPath.encode(margin),
        ]),
      line(
        "whiteboard",
        ["action": "shape_snap", "board": "b1", "kind": "ellipse", "path": BoardTouchPath.encode(heldBox(hold: 0.6))]),
      line(
        "board_touch",
        [
          "action": "path", "board": "b1", "touch_type": "pencil", "phase": "ended", "picker_tool": "eraser",
          "path": BoardTouchPath.encode(writing),
        ]),
      line(
        "board_touch",
        [
          "action": "path", "board": "b1", "touch_type": "pencil", "phase": "ended",
          "path": BoardTouchPath.encode(heldBox(hold: 0.6)),
        ]),
      line("board_touch", ["action": "path", "board": "b2", "path": BoardTouchPath.encode(heldBox(hold: 0.6))]),
      line("whiteboard", ["action": "paper_touch", "board": "b1"]),
      line("whiteboard", ["action": "scratch", "board": "b1", "fired": false, "why": "slow"]),
      "not json",
    ].joined(separator: "\n")

    let cases = BoardTouchReplay.cases(fromLog: log, board: "b1")
    XCTAssertEqual(
      cases.map(\.kind), [.scratch, .marginHold, .snap, .touch], "writing stays out; a line with no path is no case")
    XCTAssertEqual(cases[0].host, .init(scratch: "zigzag", reversals: 4))
    XCTAssertEqual(cases[0].phone?["fired"], "true")
    XCTAssertEqual(BoardTouchReplay.agrees(cases[0]), true)
    XCTAssertEqual(cases[1].host, .init(margin: "hold"))
    XCTAssertEqual(BoardTouchReplay.agrees(cases[1]), true)
    XCTAssertEqual(cases[2].host, .init(snap: "rectangle"))
    XCTAssertEqual(BoardTouchReplay.agrees(cases[2]), false, "the iPad said ellipse")
    XCTAssertEqual(cases[3].host, .init(held: true, snap: "rectangle"))
    XCTAssertEqual(cases[3].phase, "ended")
    XCTAssertNil(BoardTouchReplay.agrees(cases[3]))
    XCTAssertEqual(cases.map(\.expect), cases.map(\.host))
    XCTAssertTrue(cases[0].name.contains("iPad: fired"), cases[0].name)

    let every = BoardTouchReplay.cases(fromLog: log, all: true)
    XCTAssertEqual(every.filter { $0.kind == .touch }.count, 3, "with all, writing too, and every board")
    XCTAssertEqual(every.first { $0.pickerTool == "eraser" }?.host, .init(held: false))
  }

  func testAFixtureCaseSurvivesItsJSON() throws {
    let fixture = BoardTouchReplay.Fixture(
      source: "test",
      cases: BoardTouchReplay.cases(
        fromLog: line(
          "board_touch", ["action": "path", "touch_type": "pencil", "path": BoardTouchPath.encode(heldBox(hold: 0.7))]))
    )
    let data = try JSONEncoder().encode(fixture)
    XCTAssertEqual(try JSONDecoder().decode(BoardTouchReplay.Fixture.self, from: data), fixture)
    XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"touch_type\""))
  }

  // MARK: - The fixtures

  /// Every fixture `just touch-fixture` wrote (`Fixtures/touches`): each case's path still gets its expected verdict.
  func testEveryTouchFixtureKeepsItsVerdicts() throws {
    let folder = Self.fixtures.appendingPathComponent("touches")
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }
    XCTAssertFalse(files.isEmpty)
    for file in files {
      let fixture = try JSONDecoder().decode(BoardTouchReplay.Fixture.self, from: Data(contentsOf: file))
      XCTAssertFalse(fixture.cases.isEmpty, file.lastPathComponent)
      for c in fixture.cases {
        let samples = try XCTUnwrap(BoardTouchPath.decode(c.path), c.name)
        XCTAssertEqual(
          BoardTouchReplay.verdict(c.kind, samples, touchType: c.touchType), c.expect,
          "\(file.lastPathComponent): \(c.name)")
      }
    }
  }
}
