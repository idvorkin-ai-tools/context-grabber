//  Stories 437, 439, 529, 532–534: the trial on paper's arithmetic.

import ContextCore
import CoreGraphics
import XCTest

final class PaperProbeTests: XCTestCase {
  private let oldInk = CGRect(x: 10_100, y: 9_900, width: 300, height: 500)

  func testAColumnStartsAtTheInkWhenItStaysInPlace() {
    let column = PaperProbe.column(ink: oldInk, layout: .inkInPlace)
    XCTAssertEqual(column.origin, CGPoint(x: 10_060, y: 9_860))
    XCTAssertEqual(column.shift, .zero)
    XCTAssertEqual(column.width, 820)
    XCTAssertEqual(column.pages, 2, "the ink's page and a blank one")
    XCTAssertEqual(column.bounds, CGRect(x: 10_060, y: 9_860, width: 820, height: 2_120))
  }

  func testMovedInkSitsAtTheCornerOfAColumnAtTheOrigin() {
    let column = PaperProbe.column(ink: oldInk, layout: .moved)
    XCTAssertEqual(column.origin, .zero)
    XCTAssertEqual(column.shift, CGVector(dx: -10_060, dy: -9_860))
    XCTAssertEqual(column.heldPages, column.pages)
    XCTAssertEqual(column.trim, 0)
  }

  func testATallColumnHoldsMoreThanItShows() {
    let column = PaperProbe.column(ink: oldInk, layout: .tall)
    XCTAssertEqual(column.pages, 2)
    XCTAssertEqual(column.heldPages, 40)
    XCTAssertEqual(column.trim, 38 * 1060)
  }

  func testInkTallerThanThePagesHeldStaysHeld() {
    let tall = CGRect(x: 0, y: 0, width: 100, height: 60 * 1060)
    let column = PaperProbe.column(ink: tall, layout: .tall)
    XCTAssertEqual(column.heldPages, column.pages)
    XCTAssertGreaterThan(column.pages, 60)
  }

  func testWideInkWidensTheColumn() {
    XCTAssertEqual(PaperProbe.column(ink: CGRect(x: 0, y: 0, width: 2_000, height: 10), layout: .moved).width, 2_080)
  }

  func testAnEmptyBoardIsTwoPagesFromTheOldMiddle() {
    for ink in [nil, CGRect.null, CGRect.zero] {
      let column = PaperProbe.column(ink: ink, layout: .inkInPlace)
      XCTAssertEqual(column.origin, PaperProbe.oldMiddle)
      XCTAssertEqual(column.pages, 2)
    }
  }

  func testThePageNumberFollowsTheBoardAndStaysInTheColumn() {
    let column = PaperProbe.column(ink: oldInk, layout: .inkInPlace)
    XCTAssertEqual(column.page(at: column.origin.y + 10), 1)
    XCTAssertEqual(column.page(at: column.origin.y + 1_060), 2)
    XCTAssertEqual(column.page(at: column.origin.y - 500), 1)
    XCTAssertEqual(column.page(at: column.origin.y + 50_000), 2)
  }

  func testAPageIsNeededOnceInkReachesTheLastOne() {
    let column = PaperProbe.column(ink: oldInk, layout: .inkInPlace)
    XCTAssertFalse(column.needsPage(inkMaxY: column.origin.y + 1_060))
    XCTAssertTrue(column.needsPage(inkMaxY: column.origin.y + 1_061))
  }

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

  func testAGlideKeepsTheWorstGapAndSlip() {
    var glide = PaperProbe.Glide()
    glide.delegateCalled(at: 1)
    glide.delegateCalled(at: 1.008)
    glide.delegateCalled(at: 1.1)
    glide.tick(moved: true, stale: false, slip: 0.5)
    glide.tick(moved: true, stale: true, slip: 7)
    glide.tick(moved: false, stale: false, slip: 1)
    XCTAssertEqual(glide.delegateCalls, 3)
    XCTAssertEqual(glide.maxGap, 0.092, accuracy: 0.0001)
    XCTAssertEqual(glide.ticks, 3)
    XCTAssertEqual(glide.movedTicks, 2)
    XCTAssertEqual(glide.staleTicks, 1)
    XCTAssertEqual(glide.maxSlip, 7)
  }

  func testARoundTripSaysWhatChanged() {
    let same = PaperProbe.roundTrip(["a", "b"], ["a", "b"])
    XCTAssertTrue(same.sameOrder)
    XCTAssertEqual(same.missing, 0)
    XCTAssertEqual(same.extra, 0)
    let reordered = PaperProbe.roundTrip(["a", "b"], ["b", "a"])
    XCTAssertFalse(reordered.sameOrder)
    XCTAssertEqual(reordered.missing, 0)
    let changed = PaperProbe.roundTrip(["a", "b", "c"], ["a", "x"])
    XCTAssertEqual(changed.firstMissing, ["b", "c"])
    XCTAssertEqual(changed.extra, 1)
    XCTAssertEqual(changed.countBack, 2)
  }
}
