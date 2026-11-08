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
