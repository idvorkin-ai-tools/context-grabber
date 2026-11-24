import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the whiteboard spec's *Scratch out* (stories 890, 891), and the Cockpit web board's own cases
/// (assets/ink/test_board.mjs, *scratch-out*), ported with the same zigzags, humps and loops so both boards agree.
final class WhiteboardScratchOutTests: XCTestCase {
  typealias Scratch = WhiteboardScratchOut

  /// A hand zigzag: n sweeps between x0 and x0+w, drifting down h in all, a little ragged at the turns.
  private func zigzag(
    _ n: Int, _ x0: CGFloat, _ y0: CGFloat, _ w: CGFloat, _ h: CGFloat, vertical: Bool = false, slant: CGFloat = 0
  ) -> [CGPoint] {
    var points: [CGPoint] = []
    for i in 0...n {
      let short = CGFloat((i * 7) % 3) * 0.05 * w
      let x = i % 2 == 1 ? x0 + w - short : x0 + short
      let y = y0 + h * CGFloat(i) / CGFloat(n) + slant * CGFloat(i % 2)
      if let last = points.last {
        for k in 1..<6 {
          points.append(CGPoint(x: last.x + (x - last.x) * CGFloat(k) / 6, y: last.y + (y - last.y) * CGFloat(k) / 6))
        }
      }
      points.append(CGPoint(x: x, y: y))
    }
    return vertical ? points.map { CGPoint(x: $0.y, y: $0.x) } : points
  }

  /// Handwriting humps: "mmm", "www", a cursive "minimum", a single "m".
  private func humps(_ count: Int, _ x0: CGFloat, _ y0: CGFloat, _ wEach: CGFloat, _ h: CGFloat, down: Bool = true)
    -> [CGPoint]
  {
    var points: [CGPoint] = []
    for i in 0..<(count * 2) {
      for k in 0...8 {
        let t = CGFloat(k) / 8
        let x = x0 + (CGFloat(i) + t) * (wEach / 2)
        let arch = sin(t * .pi) * h
        points.append(CGPoint(x: x, y: down ? y0 + h - arch * (i % 2 == 1 ? 0.2 : 1) : y0 + arch))
      }
    }
    return points
  }

  private func loops(_ count: Int, _ x0: CGFloat, _ y0: CGFloat, _ r: CGFloat) -> [CGPoint] {
    var points: [CGPoint] = []
    for i in 0..<count {
      for k in 0...16 {
        let a = CGFloat(k) / 16 * 2 * .pi
        points.append(
          CGPoint(x: x0 + CGFloat(i) * r * 1.6 + r * cos(a) + CGFloat(k) / 16 * r * 1.6, y: y0 + r * sin(a)))
      }
    }
    return points
  }

  /// A line of "writing": a wiggly stroke spanning y...y+24 at x0...x0+w.
  private func line(_ id: String, _ y: CGFloat, _ x0: CGFloat = 100, _ w: CGFloat = 300) -> Scratch.Ink {
    let points = stride(from: x0, through: x0 + w, by: 20).map { x in
      CGPoint(x: x, y: y + (Int(x / 20) % 2 == 1 ? 24 : 0))
    }
    return Scratch.Ink(id: id, points: points, width: 2)
  }

  func testRealZigzagsQualify() {
    let cases: [(Int, CGFloat, CGFloat, Bool, CGFloat)] = [
      (4, 120, 24, false, 0), (5, 260, 30, false, 0), (6, 80, 40, false, 0), (7, 300, 20, false, 6),
      (5, 60, 30, true, 0),
    ]
    for (n, w, h, vertical, slant) in cases {
      let shape = Scratch.shape(zigzag(n, 100, 100, w, h, vertical: vertical, slant: slant))
      XCTAssertTrue(shape.ok, "zigzag \(n) sweeps \(w)x\(h): \(shape.why ?? "") (\(shape.reversals) turns)")
      XCTAssertGreaterThanOrEqual(shape.reversals, Scratch.reversals)
    }
  }

  func testHandwritingNeverQualifies() {
    let underline = [100, 200, 300, 400, 500, 600, 700, 750].enumerated().map { i, x in
      CGPoint(x: CGFloat(x), y: CGFloat(100 + (i % 2 == 1 ? 1 : 0)))
    }
    let cases: [String: [CGPoint]] = [
      "mmm": humps(3, 100, 100, 40, 30), "www": humps(3, 100, 100, 40, 30, down: false),
      "m": humps(1, 100, 100, 36, 30),
      "wide m": humps(1, 100, 100, 50, 30), "minimum": humps(7, 100, 100, 26, 22), "eee": loops(3, 100, 100, 14),
      "ooo": loops(3, 100, 100, 20), "big ooo": loops(5, 100, 100, 30), "two sweeps": zigzag(2, 100, 100, 200, 20),
      "underline": underline,
    ]
    for (name, points) in cases {
      let shape = Scratch.shape(points)
      XCTAssertFalse(shape.ok, "\(name) read as a scratch-out (\(shape.reversals) turns)")
    }
  }

  /// context-grabber-4kj: a zigzag whose sweeps cross about 60% of its length, drifting along as a hand does.
  private func wandering(_ n: Int, _ x0: CGFloat, _ y0: CGFloat, _ sweep: CGFloat, _ drift: CGFloat) -> [CGPoint] {
    var points: [CGPoint] = []
    for i in 0...n {
      let x = x0 + drift * CGFloat(i) / CGFloat(n) + (i % 2 == 1 ? sweep : 0)
      let y = y0 + CGFloat(i % 2) * 20
      if let last = points.last {
        for k in 1..<6 {
          points.append(CGPoint(x: last.x + (x - last.x) * CGFloat(k) / 6, y: last.y + (y - last.y) * CGFloat(k) / 6))
        }
      }
      points.append(CGPoint(x: x, y: y))
    }
    return points
  }

  /// context-grabber-4kj, the oracle: Igor's own scribbles on 2026-11-21 (board 65167d7d, Cockpit thread
  /// igor2-88g.1575; and one on the web board), which all stayed ink on *short sweeps*, and the hatching on his boards
  /// that must stay ink. Each case says what `check` must find, and which strokes go.
  func testIgorsRealScribblesScratchOutAndHisHatchingStaysInk() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/scratch-out/igor-2026-11-21.json")
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
    XCTAssertEqual(cases.count, 7)
    func points(_ any: Any?) -> [CGPoint] {
      (any as? [[Double]] ?? []).map { CGPoint(x: $0[0], y: $0[1]) }
    }
    for c in cases {
      let name = c["name"] as? String ?? "?"
      let ink = (c["ink"] as? [[String: Any]] ?? []).map {
        Scratch.Ink(
          id: $0["id"] as? String ?? "", points: points($0["points"]), width: CGFloat($0["width"] as? Double ?? 3))
      }
      let outcome = Scratch.check(points(c["points"]), ms: c["ms"] as? Double, over: ink)
      let why = c["why"] as? String
      XCTAssertEqual(outcome.why, why, name)
      XCTAssertEqual(outcome.ok, why == nil, name)
      XCTAssertEqual(Set(outcome.gone), Set(c["gone"] as? [String] ?? []), name)
      XCTAssertFalse(outcome.findsNothing, "\(name): stays ink unsaid, or scratches out")
    }
  }

  func testAScribbleThatWandersAlongAWordTakesIt() {
    let word = line("word", 100, 100, 200)
    let zig = wandering(8, 95, 104, 130, 80)
    let shape = Scratch.shape(zig)
    XCTAssertTrue(shape.ok, shape.why ?? "")
    XCTAssertTrue(shape.wanders)
    let outcome = Scratch.check(zig, ms: 800, over: [word, line("below", 300)])
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(outcome.gone, ["word"])
    // Over a fold's marker, where there is no ink, it takes the fold as a zigzag does (story 905).
    XCTAssertTrue(Scratch.isZigzag(zig, ms: 800))
  }

  func testAWanderingScribbleNeedsFiveTurnsAndStaysInkOverNothing() {
    XCTAssertEqual(Scratch.shape(wandering(4, 95, 104, 130, 80)).why, "short sweeps", "four turns: writing or hatching")
    XCTAssertEqual(Scratch.shape(wandering(8, 95, 104, 35, 160)).why, "few turns", "letter-wide sweeps")
    let bare = Scratch.check(wandering(8, 95, 400, 130, 80), ms: 800, over: [line("word", 100, 100, 200)])
    XCTAssertEqual(bare.why, "wanders, no ink", "over bare paper it is hatching: it stays ink")
    XCTAssertFalse(bare.findsNothing)
    // A full-length zigzag over bare paper still goes, with a word (#1000).
    XCTAssertTrue(Scratch.check(zigzag(5, 95, 400, 210, 26), ms: 600, over: [line("word", 100)]).findsNothing)
  }

  func testAFastZigzagOverAWordTakesItAndNothingElse() {
    let ink = [line("a", 100, 100, 200), line("b", 100, 340, 200), line("c", 300)]
    let zig = zigzag(5, 95, 98, 210, 26)
    let outcome = Scratch.check(zig, ms: 600, over: ink)
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(outcome.gone, ["a"], "the word beside it and the line below stay")
    XCTAssertGreaterThanOrEqual(outcome.reversals, 3)
    XCTAssertGreaterThan(outcome.speed ?? 0, Scratch.speed)
  }

  func testAZigzagThatIsNotAScratchOutStaysInk() {
    let ink = [line("a", 100, 100, 200), line("b", 100, 340, 200), line("c", 300)]
    let zig = zigzag(5, 95, 98, 210, 26)
    XCTAssertEqual(Scratch.check(zigzag(5, 95, 200, 210, 26), ms: 600, over: ink).why, "no ink", "over bare paper")
    XCTAssertEqual(Scratch.check(zig, ms: 60_000, over: ink).why, "slow", "drawn slowly")
    let mmm = Scratch.check(humps(3, 100, 98, 60, 26), ms: 300, over: ink)
    XCTAssertFalse(mmm.ok, "mmm written over a word stays ink")
    XCTAssertEqual(mmm.gone, [])
  }

  func testAZigzagBesideAWordRatherThanOverItStaysInk() {
    // A long word only clipped by the zigzag's end: most of its ink lies outside the zigzag.
    let long = line("long", 100, 280, 500)
    let outcome = Scratch.check(zigzag(5, 95, 98, 200, 26), ms: 600, over: [long])
    XCTAssertEqual(outcome.why, "beside ink")
  }

  func testAnUnknownTimeIsNotHeldToTheSpeed() {
    let outcome = Scratch.check(zigzag(5, 95, 98, 210, 26), ms: nil, over: [line("a", 100, 100, 200)])
    XCTAssertTrue(outcome.ok)
    XCTAssertNil(outcome.speed)
  }

  func testAStrokeIsTakenByItsPenNotOnlyItsLine() {
    // A dot of a thick pen a little off the zigzag's line is still under it.
    let dot = Scratch.Ink(id: "dot", points: [CGPoint(x: 150, y: 120)], width: 10)
    let zig = [CGPoint(x: 100, y: 112), CGPoint(x: 200, y: 112)]
    XCTAssertEqual(Scratch.touched(by: zig, in: [dot]), ["dot"])
    let far = Scratch.Ink(id: "far", points: [CGPoint(x: 150, y: 140)], width: 10)
    XCTAssertEqual(Scratch.touched(by: zig, in: [far]), [])
  }

  /// #999: the simulator's stand-in zigzag, across a straight stroke drawn over a word, is a scratch-out of that word and
  /// nothing beside it, so a UI test can reach the scratch-out's PaperKit path.
  func testTheSimulatorsZigzagAcrossAStrokeScratchesOutTheWordUnderIt() {
    let word = Scratch.Ink(id: "word", points: stride(from: 100, through: 300, by: 10).map { CGPoint(x: $0, y: 100) })
    let below = Scratch.Ink(id: "below", points: [CGPoint(x: 150, y: 160), CGPoint(x: 250, y: 160)])
    let zig = Scratch.zigzag(across: CGRect(x: 90, y: 99, width: 220, height: 3))
    XCTAssertGreaterThanOrEqual(Scratch.shape(zig.points).reversals, Scratch.reversals)
    let outcome = Scratch.check(zig.points, ms: zig.ms, over: [word, below])
    XCTAssertTrue(outcome.ok, "why: \(outcome.why ?? "-")")
    XCTAssertEqual(outcome.gone, ["word"])
    XCTAssertTrue(Scratch.isZigzag(Scratch.zigzag(across: CGRect(x: 0, y: 0, width: 3, height: 120)).points, ms: 100))
  }

  func testTheZigzagHookReadsItsStrokeCount() {
    XCTAssertEqual(WhiteboardHooks(["GRABBER_WHITEBOARD_ZIGZAG": "2"]).zigzagAt, 2)
    XCTAssertNil(WhiteboardHooks([:]).zigzagAt)
  }

  /// Stories 1051, 1052 (#1000): only a real zigzag that found nothing to erase says so and goes; writing stays ink, unsaid.
  func testOnlyAZigzagOverNothingFindsNothing() {
    func outcome(_ ok: Bool, _ why: String?) -> Scratch.Outcome {
      Scratch.Outcome(ok: ok, gone: [], reversals: 4, speed: 1, why: why)
    }
    XCTAssertTrue(outcome(false, "no ink").findsNothing)
    XCTAssertTrue(outcome(false, "beside ink").findsNothing)
    for why in [
      "slow", "marches along", "short sweeps", "few turns", "short", "small", "wanders, no ink", "wanders, beside ink",
    ] {
      XCTAssertFalse(outcome(false, why).findsNothing, why)
    }
    XCTAssertFalse(outcome(true, nil).findsNothing, "one that worked")
  }

  /// #966, #999, context-grabber-geaz: the board's take-back of a zigzag undid PaperKit's newest step; it is redone when
  /// that step was not the zigzag's. The oracle: the zigzag's own step takes the zigzag and nothing else.
  func testATakeBackIsRedoneWhenTheStepItUndidWasNotTheZigzags() {
    let ink: Set<String> = ["a", "b"]
    XCTAssertFalse(
      Scratch.redoTakeBack(could: false, zigzagHeld: true, held: ink, before: ink),
      "nothing taken back, nothing to redo")
    XCTAssertFalse(
      Scratch.redoTakeBack(could: true, zigzagHeld: false, held: ink, before: ink), "the zigzag's step: it stays undone"
    )
    XCTAssertTrue(
      Scratch.redoTakeBack(could: true, zigzagHeld: true, held: ["a"], before: ink), "a step that took ink is put back")
    XCTAssertTrue(
      Scratch.redoTakeBack(could: true, zigzagHeld: true, held: ink.union(["c"]), before: ink),
      "a step that added ink is put back")
    // A lasso move keeps every stroke's key: only the zigzag still on the board tells it was the wrong step.
    XCTAssertTrue(
      Scratch.redoTakeBack(could: true, zigzagHeld: true, held: ink, before: ink), "a step that moved ink is put back")
  }

  // MARK: - Ink the pixel eraser rubbed out (context-grabber-p5hy)

  /// `line` with only the parts whose x is in `keep` left on the board.
  private func rubbed(_ id: String, _ y: CGFloat, keep: [ClosedRange<CGFloat>]) -> Scratch.Ink {
    let whole = line(id, y)
    return Scratch.Ink(id: id, runs: keep.map { k in whole.points.filter { k.contains($0.x) } }, width: whole.width)
  }

  func testAZigzagOverTheGapTheEraserLeftStaysInk() {
    let scratch = zigzag(5, 200, 95, 100, 30)
    // The whole stroke runs under it, so the zigzag touches it.
    XCTAssertEqual(Scratch.touched(by: scratch, in: [line("a", 100)]), ["a"])
    XCTAssertEqual(Scratch.touched(by: scratch, in: [rubbed("a", 100, keep: [100...180, 320...400])]), [])
    // Its middle rubbed out, only the two ends are left, and the zigzag lies over the bare paper between.
    let outcome = Scratch.check(scratch, ms: 100, over: [rubbed("a", 100, keep: [100...180, 320...400])])
    XCTAssertFalse(outcome.ok)
    XCTAssertEqual(outcome.gone, [])
    XCTAssertEqual(outcome.why, "no ink")
  }

  func testAZigzagOverWhatIsLeftTakesTheStroke() {
    let outcome = Scratch.check(
      zigzag(5, 260, 95, 140, 30), ms: 100, over: [rubbed("a", 100, keep: [100...140, 260...400]), line("b", 300)])
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(outcome.gone, ["a"])
  }

  func testWhatTheEraserLeftIsReadFromTheVisibleRanges() {
    let points = (0..<5).map { CGPoint(x: CGFloat($0) * 10, y: 0) }
    let at = { (t: CGFloat) in CGPoint(x: t * 10, y: 1) }
    // Unrubbed: the points as they are.
    XCTAssertEqual(Scratch.runs(points, visible: [0...4], at: at), [points])
    // The middle rubbed out: two stretches, their cut ends read between the points.
    XCTAssertEqual(
      Scratch.runs(points, visible: [0...1.5, 2.5...4], at: at),
      [[points[0], points[1], CGPoint(x: 15, y: 1)], [CGPoint(x: 25, y: 1), points[3], points[4]]])
    // Rubbed out entirely: nothing, and no ink.
    XCTAssertEqual(Scratch.runs(points, visible: [], at: at), [])
    XCTAssertTrue(Scratch.Ink(id: "a", runs: []).runs.isEmpty)
  }

  /// context-grabber-4kj, 2026-11-22: pen paths from Igor's iPad session logs. The scribble that drifted 458 points
  /// along, sweeps 87 to 245, now reads as a wandering scribble; every other stroke's verdict is the one the app gave:
  /// his fast handwriting and his near misses (*marches along*, *slow*, *short sweeps*) stay ink.
  func testIgorsLoggedPenPathsKeepTheirVerdictAndTheDriftingScribbleCounts() throws {
    let cases = try loggedPaths()
    XCTAssertEqual(cases.count, 52)
    for c in cases {
      let ms = c.samples.last?.ms
      XCTAssertEqual(Scratch.isZigzag(c.samples.map(\.point), ms: ms), c.zigzag, "\(c.name) at \(c.log)")
    }
  }

  func testTheDriftingScribbleTakesTheInkUnderItAndStaysInkOverNothing() throws {
    let scribble = try XCTUnwrap(try loggedPaths().first { $0.log == "grabber-20261121-190304.jsonl:307" })
    let points = scribble.samples.map(\.point)
    let ms = scribble.samples.last?.ms
    let shape = Scratch.shape(points)
    XCTAssertTrue(shape.ok, shape.why ?? "")
    XCTAssertTrue(shape.wanders)
    XCTAssertGreaterThanOrEqual(shape.reversals, Scratch.wanderingReversals)
    // Synthetic ink: a phrase along the line it crossed (the log doesn't hold what was under it).
    let words = stride(from: CGFloat(370), through: 760, by: 70).map { line("w\(Int($0))", 350, $0, 50) }
    let outcome = Scratch.check(points, ms: ms, over: words + [line("below", 520, 360, 300)])
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(Set(outcome.gone), Set(words.map(\.id)))
    XCTAssertEqual(Scratch.check(points, ms: ms, over: [line("below", 520, 360, 300)]).why, "wanders, no ink")
  }

  /// The same drift, with sweeps a letter wide, stays ink: handwriting's back-and-forth is narrower than 40 points.
  func testADriftWithLetterWideSweepsStaysInk() {
    XCTAssertFalse(Scratch.shape(wandering(12, 95, 104, 30, 400)).ok)
    XCTAssertTrue(Scratch.shape(wandering(12, 95, 104, 90, 400)).ok)
  }

  /// cockpit-9g1, the oracle: Igor's scratch-out on board-nov-23 (2026-11-23 06:42) over ten fresh strokes, which left
  /// one, a mark its sweeps passed either side of; and the retry over that mark, a 37-point zigzag refused as slow.
  private func leftOne() throws -> [(name: String, points: [CGPoint], ms: Double, ink: [Scratch.Ink])] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/scratch-out/igor-left-one-2026-11-23.json")
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    func points(_ any: Any?) -> [CGPoint] {
      (any as? [[Double]] ?? []).map { CGPoint(x: $0[0], y: $0[1]) }
    }
    return try XCTUnwrap(root["cases"] as? [[String: Any]]).map { c in
      let ink = (c["ink"] as? [[String: Any]] ?? []).map {
        Scratch.Ink(id: $0["id"] as? String ?? "", points: points($0["pts"]), width: CGFloat($0["w"] as? Double ?? 3))
      }
      return (c["name"] as? String ?? "?", points(c["pts"]), c["ms"] as? Double ?? 0, ink)
    }
  }

  /// Story 1282: the mark between two sweeps goes with the word, and the line of writing above stays.
  func testAMarkInsideTheStruckWordGoesWithIt() throws {
    let scratch = try XCTUnwrap(try leftOne().first { $0.name == "the scratch-out" })
    let outcome = Scratch.check(scratch.points, ms: scratch.ms, over: scratch.ink)
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    let word = ["bj", "bl", "bn", "bp", "br", "bt", "bv", "bx", "bz", "c1"].map { "smwtdf6\($0)" }
    XCTAssertEqual(Set(outcome.gone), Set(word))
  }

  /// Story 1282: a mark inside a struck word, between two sweeps, goes; the line below stays, however close.
  func testAMarkBetweenTwoSweepsGoesAndTheLineBelowStays() {
    // A word with a tall letter, and four sweeps 15 points apart drifting down across it.
    let word = line("word", 100, 100, 200)
    let tall = Scratch.Ink(id: "tall", points: [CGPoint(x: 110, y: 100), CGPoint(x: 110, y: 160)], width: 2)
    let zig = [(95, 100), (305, 115), (95, 130), (305, 145), (95, 160)].map { CGPoint(x: $0.0, y: $0.1) }
      .reduce(into: [CGPoint]()) { points, end in
        guard let last = points.last else { return points.append(end) }
        for k in 1...10 {
          let t = CGFloat(k) / 10
          points.append(CGPoint(x: last.x + (end.x - last.x) * t, y: last.y + (end.y - last.y) * t))
        }
      }
    // Midway between the second and the third sweep, seven and a half points from each: no sweep touches it.
    let between = Scratch.Ink(id: "between", points: [CGPoint(x: 199, y: 130), CGPoint(x: 201, y: 130)], width: 1)
    let below = line("below", 175, 100, 200)
    let outcome = Scratch.check(zig, ms: 600, over: [word, tall, between, below])
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(Set(outcome.gone), ["word", "tall", "between"])
  }

  /// Story 1283: the retry, 37 points at 0.35 points per millisecond, now scratches the mark out.
  func testASmallZigzagScratchesOutAtASmallZigzagsSpeed() throws {
    let retry = try XCTUnwrap(try leftOne().first { $0.name == "the retry" })
    let outcome = Scratch.check(retry.points, ms: retry.ms, over: retry.ink)
    XCTAssertTrue(outcome.ok, outcome.why ?? "")
    XCTAssertEqual(outcome.gone, ["smwtdf6bn"])
  }

  /// Story 1283: the floor is half a point per millisecond from 60 points, a quarter at 30.
  func testTheSpeedFloorScalesWithTheZigzagsLength() {
    XCTAssertEqual(Scratch.speedFloor(length: 120), 0.5)
    XCTAssertEqual(Scratch.speedFloor(length: 60), 0.5)
    XCTAssertEqual(Scratch.speedFloor(length: 30), 0.25)
    XCTAssertEqual(Scratch.speedFloor(length: 45), 0.375)
  }

  private func loggedPaths() throws -> [(name: String, log: String, zigzag: Bool, samples: [BoardTouchPath.Sample])] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/scratch-out/igor-ipad-paths-2026-11-22.json")
    let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    return try XCTUnwrap(root["cases"] as? [[String: Any]]).map {
      (
        $0["name"] as? String ?? "?", $0["log"] as? String ?? "?", $0["zigzag"] as? Bool ?? false,
        BoardTouchPath.decode($0["path"] as? String ?? "") ?? []
      )
    }
  }
}
