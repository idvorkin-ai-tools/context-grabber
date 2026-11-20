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
      "ooo": loops(3, 100, 100, 20), "two sweeps": zigzag(2, 100, 100, 200, 20), "underline": underline,
    ]
    for (name, points) in cases {
      let shape = Scratch.shape(points)
      XCTAssertFalse(shape.ok, "\(name) read as a scratch-out (\(shape.reversals) turns)")
    }
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
    for why in ["slow", "marches along", "short sweeps", "few turns", "short", "small"] {
      XCTAssertFalse(outcome(false, why).findsNothing, why)
    }
    XCTAssertFalse(outcome(true, nil).findsNothing, "one that worked")
  }
}
