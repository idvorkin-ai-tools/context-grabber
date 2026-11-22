//  Stories 437, 439, 529, 532–534: what a board on paper logs about a touch and the ink it moved.

import ContextCore
import XCTest

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class PaperProbeTests: XCTestCase {
  func testInkChangeNamesWhatMovedByHowMuch() {
    let before = [
      "a": CGRect(x: 0, y: 0, width: 10, height: 10), "b": CGRect(x: 5, y: 5, width: 10, height: 10),
      "c": CGRect(x: 9, y: 9, width: 1, height: 1),
    ]
    let after = [
      "a": CGRect(x: 0, y: 0, width: 10, height: 10), "b": CGRect(x: 8, y: 1, width: 10, height: 10),
      "d": CGRect(x: 1, y: 1, width: 1, height: 1),
    ]
    let change = PaperProbe.inkChange(before: before, after: after)
    XCTAssertEqual(change.added, ["d"])
    XCTAssertEqual(change.removed, ["c"])
    XCTAssertEqual(change.moved, [PaperProbe.InkMove(id: "b", dx: 3, dy: -4, resized: false)])
    XCTAssertFalse(change.isEmpty)
  }

  func testAResizeIsSaidAndNoChangeIsEmpty() {
    let before = ["a": CGRect(x: 0, y: 0, width: 10, height: 10)]
    XCTAssertTrue(PaperProbe.inkChange(before: before, after: before).isEmpty)
    let change = PaperProbe.inkChange(before: before, after: ["a": CGRect(x: 0, y: 0, width: 20, height: 10)])
    XCTAssertEqual(change.moved.first?.resized, true)
  }

  func testATouchIsCalledWhatItDid() {
    var facts = PaperProbe.TouchFacts()
    XCTAssertEqual(PaperProbe.outcome(facts), ["nothing"])
    XCTAssertEqual(PaperProbe.gesture(facts), "tap")
    facts.travel = 200
    facts.seconds = 0.4
    XCTAssertEqual(PaperProbe.gesture(facts), "drag")
    facts.scrolled = 180
    XCTAssertEqual(PaperProbe.outcome(facts), ["panned"])
    facts.selectionChanges = 1
    facts.inkMoved = 3
    XCTAssertEqual(PaperProbe.outcome(facts), ["panned", "selected", "moved_ink"])
    facts.fingers = 2
    facts.zoomChanged = true
    XCTAssertEqual(PaperProbe.gesture(facts), "multi")
    XCTAssertTrue(PaperProbe.outcome(facts).contains("zoomed"))
  }

  func testAFingerTapIsShortStillAndAlone() {
    XCTAssertTrue(PaperProbe.isFingerTap(travel: 3, seconds: 0.1, fingers: 1))
    XCTAssertFalse(PaperProbe.isFingerTap(travel: 10, seconds: 0.1, fingers: 1), "it went somewhere")
    XCTAssertFalse(PaperProbe.isFingerTap(travel: 3, seconds: 0.5, fingers: 1), "it stayed down")
    XCTAssertFalse(PaperProbe.isFingerTap(travel: 3, seconds: 0.1, fingers: 2), "the start of a pinch")
  }

  /// Story 968: the iPad's own start views, 2026-11-22. The menu's Delete was taken for a board tap that let the selection go.
  func testATapOnTheSelectionMenuIsTheMenus() {
    XCTAssertTrue(PaperProbe.isSelectionMenu("_UIHostingView<MiniMenu<MiniMenuPalette>>"))
    for board in [
      "ShapeView", "PKSelectionGestureView", "PaperView", "HandwritingReflowView", "CanvasElementResizeHandle", "",
    ] {
      XCTAssertFalse(PaperProbe.isSelectionMenu(board), board)
    }
  }

  /// Stories 616, 825 (#883): PaperKit draws a dot where a finger taps, even in selection mode with its drawing off, a
  /// few tenths of a second after the lift; on the iPad simulator, 2026-11-14, the dot was 3 x 4 board points at the tap.
  /// While marks show, that dot is the tap's and is taken back; a stroke, or ink anywhere else or later, isn't.
  func testATapsDotIsTheSmallInkAtTheTapJustAfterIt() {
    let tap = CGPoint(x: 523.6, y: 488.2)
    let dot = CGRect(x: 522, y: 486, width: 3, height: 4)
    XCTAssertTrue(PaperProbe.isTapDot(added: [dot], tap: tap, secondsSince: 0.17, zoom: 1.02))
    XCTAssertTrue(
      PaperProbe.isTapDot(
        added: [CGRect(x: 515, y: 480, width: 12, height: 12)], tap: tap, secondsSince: 0.1, zoom: 0.5),
      "zoomed out, the same dot covers more of the board")
    XCTAssertFalse(PaperProbe.isTapDot(added: [], tap: tap, secondsSince: 0.1, zoom: 1), "nothing added")
    // Story 941: a tap that opened a kept text's field held the dot back 0.68 s and 1.3 s; it is still the tap's.
    XCTAssertFalse(PaperProbe.isTapDot(added: [dot], tap: tap, secondsSince: 0.68, zoom: 1))
    XCTAssertTrue(
      PaperProbe.isTapDot(
        added: [dot], tap: tap, secondsSince: 1.3, zoom: 1, within: PaperProbe.rewordDotSeconds))
    XCTAssertFalse(
      PaperProbe.isTapDot(added: [CGRect(x: 244, y: 486, width: 250, height: 4)], tap: tap, secondsSince: 0.1, zoom: 1),
      "a stroke")
    XCTAssertFalse(
      PaperProbe.isTapDot(added: [CGRect(x: 73, y: 746, width: 4, height: 4)], tap: tap, secondsSince: 0.1, zoom: 1),
      "a dot somewhere else")
    XCTAssertFalse(PaperProbe.isTapDot(added: [dot], tap: tap, secondsSince: 1.5, zoom: 1), "long after the tap")
    XCTAssertFalse(PaperProbe.isTapDot(added: [dot, dot], tap: tap, secondsSince: 0.1, zoom: 1), "more than a dot")
    // Story 947 (bead context-grabber-z93g): a group tap's dot, held back 1.17 s by a busy simulator, is still its dot.
    XCTAssertTrue(
      PaperProbe.isTapDot(added: [dot], tap: tap, secondsSince: 1.17, zoom: 1.02, within: PaperProbe.groupTapSeconds))
  }

  func testALongStillTouchIsAPress() {
    var facts = PaperProbe.TouchFacts()
    facts.seconds = 1
    XCTAssertEqual(PaperProbe.gesture(facts), "press")
  }

  func testAStrokeIsDrawnOnceItBeginsEvenIfItNeverLands() {
    var facts = PaperProbe.TouchFacts()
    facts.beganDrawing = true
    XCTAssertEqual(PaperProbe.outcome(facts), ["drew"])
    facts.inkRemoved = 1
    XCTAssertEqual(PaperProbe.outcome(facts), ["drew", "erased"])
  }
}

/// #825: a touch run is typed by every touch in it, not its first.
final class PaperTouchTallyTests: XCTestCase {
  func testAPalmFirstThenThePencilIsThePencils() {
    var tally = PaperProbe.TouchTally()
    tally.down(1, "finger", radius: 40)
    tally.down(2, "pencil", radius: 0.5)
    XCTAssertEqual(tally.type, "pencil")
    XCTAssertEqual(tally.types, ["finger": 1, "pencil": 1])
    XCTAssertEqual(tally.fingerRadius, 40)
  }

  func testFingersAloneAreAFingers() {
    var tally = PaperProbe.TouchTally()
    tally.down(1, "finger", radius: 8)
    tally.down(2, "finger", radius: 9)
    XCTAssertEqual(tally.type, "finger")
    XCTAssertEqual(tally.types, ["finger": 2])
    XCTAssertEqual(tally.fingerRadius, 9)
  }

  func testATouchCountsOnceAndANewRunStartsClean() {
    var tally = PaperProbe.TouchTally()
    tally.down(1, "pencil", radius: 0.5)
    tally.down(1, "pencil", radius: 0.5)
    XCTAssertEqual(tally.types, ["pencil": 1], "the same touch reported twice")
    tally = PaperProbe.TouchTally()
    tally.down(3, "finger", radius: 7)
    XCTAssertEqual(tally.type, "finger")
    XCTAssertNil(PaperProbe.TouchTally().type, "nothing touched")
  }
}
