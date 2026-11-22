import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the shapes spec's *When he has stopped writing* (stories 892, 893) and the Cockpit web board's own
/// cases (assets/ink/test_turns.mjs, *writing VAD*), ported with the same rhythm so both boards wait alike.
final class WhiteboardWritingVadTests: XCTestCase {
  typealias Vad = WhiteboardWritingVad
  private let t0 = ContinuousClock.now

  private func at(_ ms: Int) -> ContinuousClock.Instant { t0 + .milliseconds(ms) }

  /// He writes words of 3 strokes, 250 ms between strokes, 450 ms between words, along a line from x = 80, the last
  /// stroke ending at `endX` when given. Returns the time of the last lift, in ms.
  @discardableResult
  private func write(_ vad: inout Vad, words: Int, from start: Int = 0, y: CGFloat = 100, endX: CGFloat? = nil) -> Int {
    var t = start
    for w in 0..<words {
      for s in 0..<3 {
        vad.down(at: at(t))
        t += 200
        let left = 80 + CGFloat(w * 90 + s * 25)
        vad.lifted(at: at(t))
        vad.stroke(CGRect(x: left, y: y, width: 22, height: 24))
        t += s < 2 ? 250 : 450
      }
    }
    if let endX {
      vad.down(at: at(t))
      t += 200
      vad.lifted(at: at(t))
      vad.stroke(CGRect(x: endX - 40, y: y, width: 40, height: 24))
    }
    return t
  }

  private func fires(_ vad: Vad, after gap: Int) -> Bool { gap >= vad.pause.ms }

  func testAPauseMidSentenceDoesNotFire() {
    var vad = Vad()
    write(&vad, words: 4)
    let pause = vad.pause
    XCTAssertTrue(pause.cue.contains("mid-line"), pause.cue)
    for gap in [500, 1200, 2000] { XCTAssertFalse(fires(vad, after: gap), "a \(gap) ms pause mid-sentence") }
    XCTAssertTrue((2000...5000).contains(pause.ms), "\(pause.ms)")
  }

  func testAPauseAtTheEndOfALineFires() {
    var vad = Vad()
    write(&vad, words: 4, endX: 790)
    XCTAssertTrue(vad.pause.cue.hasPrefix("rhythm"), vad.pause.cue)
    XCTAssertTrue(fires(vad, after: 2000), "2 s after the end of the line")
  }

  func testTheWaitFollowsHisRhythmFrom1Point5To5Seconds() {
    let edge = CGRect(x: 790, y: 0, width: 10, height: 10)
    var fast = Vad()
    var t = 0
    for _ in 0..<10 {
      fast.down(at: at(t))
      t += 100
      fast.lifted(at: at(t))
      fast.stroke(edge)
      t += 100
    }
    XCTAssertEqual(fast.median, 100)
    XCTAssertEqual(fast.pause.ms, 1500)
    var slow = Vad()
    t = 0
    for _ in 0..<10 {
      slow.down(at: at(t))
      t += 100
      slow.lifted(at: at(t))
      slow.stroke(edge)
      t += 2000
    }
    XCTAssertEqual(slow.pause.ms, 5000)
    slow.down(at: at(t + 60_000))
    XCTAssertEqual(slow.median, 2000, "a long thinking gap is not his rhythm")
  }

  func testUntilThreeGapsAreSeenTheSeedRhythmIsUsed() {
    let vad = Vad()
    XCTAssertEqual(vad.median, 350)
    XCTAssertEqual(vad.pause.ms, 1500, "4 x 350 ms, held to the floor")
  }

  func testAQuestionMarkEndsTheThoughtAtOnce() {
    var vad = Vad()
    let t = write(&vad, words: 3)
    vad.down(at: at(t))
    vad.lifted(at: at(t + 200))
    vad.stroke(CGRect(x: 400, y: 96, width: 16, height: 28))  // the hook
    vad.down(at: at(t + 400))
    vad.lifted(at: at(t + 450))
    vad.stroke(CGRect(x: 406, y: 130, width: 4, height: 4))  // the dot under it
    XCTAssertEqual(vad.pause, Vad.Pause(ms: 1500, cue: "question", median: Int(vad.median)))
    // An "i"'s dot sits above its stem, never a question.
    var i = Vad()
    i.stroke(CGRect(x: 300, y: 100, width: 4, height: 24))
    i.stroke(CGRect(x: 300, y: 90, width: 4, height: 4))
    XCTAssertFalse(i.question)
  }

  func testThePencilHoveringAtANewLineCutsThePauseToTheFloor() {
    var vad = Vad()
    let t = write(&vad, words: 4)
    let pause = vad.pauseStarted(at: at(t))
    XCTAssertGreaterThan(pause.ms, 1500)
    XCTAssertNil(vad.hovered(at: CGPoint(x: 400, y: 110), now: at(t + 300)), "still on the line")
    XCTAssertEqual(vad.hovered(at: CGPoint(x: 90, y: 160), now: at(t + 500)), .milliseconds(1000), "back at the left")
    XCTAssertNil(vad.hovered(at: CGPoint(x: 90, y: 160), now: at(t + 600)), "a pause is cut short once")
  }

  func testACueAfterTheFloorEndsThePauseAtOnce() {
    var vad = Vad()
    let t = write(&vad, words: 4)
    _ = vad.pauseStarted(at: at(t))
    XCTAssertEqual(vad.hovered(at: CGPoint(x: 90, y: 160), now: at(t + 1800)), .zero)
  }

  func testTheHandLeavingIsSeenOnlyWhereTheHoverIs() {
    var vad = Vad()
    let t = write(&vad, words: 4)
    _ = vad.pauseStarted(at: at(t))
    XCTAssertNil(vad.lookedForTheHand(now: at(t + 2000)), "no hover seen: the hand can't be seen leaving")
    _ = vad.hovered(at: CGPoint(x: 400, y: 110), now: at(t + 100))
    XCTAssertNil(vad.lookedForTheHand(now: at(t + 600)), "the Pencil hovered half a second ago")
    XCTAssertEqual(vad.lookedForTheHand(now: at(t + 1100)), .milliseconds(400))
  }

  func testNoCueWithoutAPauseUnderWay() {
    var vad = Vad()
    let t = write(&vad, words: 4)
    XCTAssertNil(vad.hovered(at: CGPoint(x: 90, y: 160), now: at(t + 500)), "no pause started")
    _ = vad.pauseStarted(at: at(t))
    vad.down(at: at(t + 300))
    XCTAssertNil(vad.hovered(at: CGPoint(x: 90, y: 160), now: at(t + 500)), "the pen went down: the pause is over")
  }
}
