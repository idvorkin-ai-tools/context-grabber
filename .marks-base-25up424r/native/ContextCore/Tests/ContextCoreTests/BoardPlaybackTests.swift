import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the whiteboard spec's *Playing a board back, as Notability does* (stories 954, 956–958): the strokes in
/// the order they were drawn, each at the hand's pace, a pause over two seconds played as half a second, strokes that
/// share a moment together, and the bar's play, pause, ±10 s, scrub and speeds.
final class BoardPlaybackTests: XCTestCase {
  typealias Playback = BoardPlayback
  typealias Stroke = BoardPlayback.Stroke

  /// A stroke begun at `t` (seconds) taking `seconds` over `points` points.
  private func stroke(_ t: TimeInterval, _ seconds: TimeInterval = 1, points: Int = 5) -> Stroke {
    Stroke(began: 1_800_000_000 + t, offsets: (0..<points).map { seconds * Double($0) / Double(points - 1) })
  }

  /// Story 958: three strokes a minute apart play in order, each at its pace, the minute between them half a second.
  func testThreeStrokesAMinuteApartPlayInOrderWithTheMinutesShort() {
    let playback = Playback([stroke(0), stroke(60), stroke(120)])
    XCTAssertEqual(playback.entries.map(\.index), [0, 1, 2])
    XCTAssertEqual(playback.entries.map(\.start), [0, 1.5, 3])
    XCTAssertEqual(playback.length, 4)
    XCTAssertEqual(playback.realSpan, 121)
    XCTAssertEqual(playback.timed, 3)
  }

  func testAShortPauseKeepsItsLength() {
    let playback = Playback([stroke(0), stroke(2.5)])
    XCTAssertEqual(playback.entries[1].start, 2.5, accuracy: 1e-9, "a 1.5 s gap, under the long pause, plays as drawn")
  }

  /// The gap runs from the latest end so far, so a short stroke begun inside a long one doesn't count a gap twice.
  func testAGapIsMeasuredFromTheLatestEnd() {
    let playback = Playback([stroke(0, 10), stroke(1, 1), stroke(11)])
    XCTAssertEqual(
      playback.entries.map(\.start), [0, 10, 12],
      "the second waits for the first; the third a second after the first ends")
  }

  /// The order is when they were drawn, not where they sit in the drawing; a tie keeps the drawing's order.
  func testOrderIsByTimeThenTheDrawingsOrder() {
    let playback = Playback([stroke(60), stroke(0), stroke(30, 0, points: 1)])
    XCTAssertEqual(playback.entries.map(\.index), [1, 2, 0])
  }

  /// A kept text's letters share one moment: they appear together, at once.
  func testStrokesSharingAMomentAppearTogether() {
    let letters = (0..<4).map { _ in stroke(10) }
    let playback = Playback([stroke(0)] + letters + [stroke(11)])
    XCTAssertEqual(Set(playback.entries[1...4].map(\.start)), [1.5])
    XCTAssertEqual(playback.entries[1...4].map(\.duration), [0, 0, 0, 0])
    XCTAssertEqual(playback.shared, 4)
    XCTAssertEqual(playback.frame(at: 1.6).shown, [0, 1, 2, 3, 4])
  }

  /// Story 958: the board starts empty, a stroke draws point by point, and the end shows the whole board.
  func testFramesDrawStrokeByStrokeFromEmpty() {
    let playback = Playback([stroke(0, 1, points: 5), stroke(60, 1, points: 5)])
    XCTAssertEqual(playback.frame(at: 0), .init(shown: [], partial: nil))
    XCTAssertEqual(playback.frame(at: 0.5), .init(shown: [0], partial: .init(index: 0, points: 3)))
    XCTAssertEqual(playback.frame(at: 1.2), .init(shown: [0], partial: nil))
    XCTAssertEqual(playback.frame(at: 2), .init(shown: [0, 1], partial: .init(index: 1, points: 3)))
    XCTAssertEqual(playback.frame(at: playback.length), .init(shown: [0, 1], partial: nil))
    XCTAssertEqual(playback.frame(at: 99), .init(shown: [0, 1], partial: nil))
  }

  /// The strokes shown keep the drawing's order, so the last frame stacks as the open board does.
  func testShownStrokesAreInTheDrawingsOrder() {
    let playback = Playback([stroke(60), stroke(0)])
    XCTAssertEqual(playback.frame(at: playback.length).shown, [0, 1])
  }

  /// A board of strokes with no pace of their own (a paste, a shape) still plays, and ends whole.
  func testInstantStrokesStillPlay() {
    let playback = Playback([stroke(0, 0, points: 1), stroke(1, 0, points: 1)])
    XCTAssertEqual(playback.length, 1)
    XCTAssertEqual(playback.timed, 0)
    XCTAssertEqual(playback.frame(at: 0).shown, [])
    XCTAssertEqual(playback.frame(at: 0.5).shown, [0])
    XCTAssertEqual(playback.frame(at: 1).shown, [0, 1])
  }

  func testAnEmptyBoardHasNothingToPlay() {
    let playback = Playback([])
    XCTAssertEqual(playback.length, 0)
    XCTAssertEqual(playback.frame(at: 0), .init(shown: [], partial: nil))
  }

  /// Offsets that can't be real never send a stroke back in time or forever.
  func testBadTimesAreKeptInBounds() {
    let playback = Playback([
      Stroke(began: .nan, offsets: [0, .infinity, -1, 0.5]), Stroke(began: 10, offsets: [0, 0.25]),
    ])
    XCTAssertEqual(playback.entries[0].offsets, [0, 0, 0, 0.5])
    XCTAssertTrue(playback.length.isFinite)
  }

  /// Story 956: a tap seeks to the start of the stroke, so the board shows as it was then, that stroke next.
  func testSeekingToAStrokesStartShowsTheBoardBeforeIt() throws {
    let playback = Playback([stroke(0), stroke(60), stroke(120)])
    let start = try XCTUnwrap(playback.start(of: 1))
    XCTAssertEqual(playback.frame(at: start).shown, [0])
    XCTAssertEqual(playback.begun(at: start), 1)
  }

  /// Story 956: the tap's stroke is the nearest within reach of those showing; bare paper is none.
  func testATapFindsTheNearestStrokeWithinReach() {
    let strokes: [(index: Int, points: [CGPoint])] = [
      (0, stride(from: 0, through: 100, by: 5).map { CGPoint(x: $0, y: 0) }),
      (2, stride(from: 0, through: 100, by: 5).map { CGPoint(x: $0, y: 50) }),
    ]
    XCTAssertEqual(Playback.nearest(CGPoint(x: 50, y: 40), among: strokes, within: 20), 2)
    XCTAssertEqual(Playback.nearest(CGPoint(x: 100, y: 10), among: strokes, within: 20), 0)
    XCTAssertNil(Playback.nearest(CGPoint(x: 50, y: 200), among: strokes, within: 20))
  }

  /// Story 954: play, pause, the end, and Play again from the start.
  func testTheClockPlaysPausesAndStopsAtTheEnd() {
    var clock = BoardPlaybackClock(length: 4)
    clock.advance(1)
    XCTAssertEqual(clock.position, 0, "it waits for Play")
    clock.play()
    clock.advance(1)
    XCTAssertEqual(clock.position, 1)
    clock.pause()
    clock.advance(1)
    XCTAssertEqual(clock.position, 1)
    clock.play()
    clock.advance(10)
    XCTAssertEqual(clock.position, 4)
    XCTAssertFalse(clock.playing)
    clock.play()
    XCTAssertEqual(clock.position, 0, "Play at the end starts again")
  }

  /// Story 954: 10 s back and on, and a scrub, stay within the playback.
  func testSkipsAndSeeksStayInside() {
    var clock = BoardPlaybackClock(length: 25)
    clock.skip(10)
    clock.skip(10)
    XCTAssertEqual(clock.position, 20)
    clock.skip(10)
    XCTAssertEqual(clock.position, 25)
    clock.skip(-30)
    XCTAssertEqual(clock.position, 0)
    clock.seek(to: 12)
    XCTAssertEqual(clock.position, 12)
  }

  /// Story 954: one button steps through Notability's speeds from 1×.
  func testSpeedsStepFromOneThroughTwoAndBack() {
    var clock = BoardPlaybackClock(length: 100)
    var seen = [clock.speed]
    for _ in 0..<5 {
      clock.nextSpeed()
      seen.append(clock.speed)
    }
    XCTAssertEqual(seen, [1, 1.25, 1.5, 2, 0.7, 1])
    clock.nextSpeed()
    clock.play()
    clock.advance(2)
    XCTAssertEqual(clock.position, 2.5, "at 1.25× two seconds play two and a half")
  }
}
