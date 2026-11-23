import XCTest

@testable import ContextCore

/// Story 1172: a drop by hand, however it was picked up. The oracle is the iPad's log of 2026-11-22 (board ead78e80): a
/// kept text of Larry's, 29 strokes, dragged from PaperKit's handwriting view with nothing selected, every stroke moved
/// 155, -153 (one of them -154, 16 of them re-measured), and the board took it for no drop.
final class PaperProbePickupTests: XCTestCase {
  private func move(_ id: String, _ dx: CGFloat, _ dy: CGFloat, resized: Bool = false) -> PaperProbe.InkMove {
    PaperProbe.InkMove(id: id, dx: dx, dy: dy, resized: resized)
  }

  /// The iPad's drag: 29 strokes, nothing selected, a finger down.
  private var ipadDrag: [PaperProbe.InkMove] {
    (0..<29).map { move("s\($0)", 155, $0 == 3 ? -154 : -153, resized: $0 < 16) }
  }

  func testTheIPadsUnselectedDragOfAKeptTextIsADrop() {
    let pickup = PaperProbe.pickup(ipadDrag, selected: [], inTouch: true, split: false)
    XCTAssertEqual(pickup, .dragged)
    XCTAssertTrue(pickup.isDrop)
  }

  func testASelectionMovedIsADropEvenWithNoTouchSeen() {
    let moved = [move("a", 10, 80), move("b", 10, 80)]
    XCTAssertEqual(PaperProbe.pickup(moved, selected: ["a", "b", "c"], inTouch: false, split: false), .selected)
  }

  func testStrokesMovedByDifferentAmountsAreTheSystemRearranging() {
    // Handwriting reflow: words of a line wrapped onto the next, each its own way.
    let moved = [move("a", 40, 0), move("b", -300, 40), move("c", 12, 0)]
    let pickup = PaperProbe.pickup(moved, selected: [], inTouch: true, split: false)
    XCTAssertEqual(pickup, .notRigid)
    XCTAssertFalse(pickup.isDrop)
  }

  func testAMoveWithNoTouchDownIsNoDrop() {
    XCTAssertEqual(PaperProbe.pickup(ipadDrag, selected: [], inTouch: false, split: false), .notInTouch)
  }

  func testAMoveCarryingBothOwnersIsPutRightNotDropped() {
    let pickup = PaperProbe.pickup(ipadDrag, selected: [], inTouch: true, split: true)
    XCTAssertEqual(pickup, .split)
    XCTAssertFalse(pickup.isDrop, "the owners-apart rule takes PaperKit's step back; a drop would take back a second")
  }

  func testNothingMovedIsNotAMove() {
    XCTAssertEqual(PaperProbe.pickup([], selected: [], inTouch: true, split: false), .notAMove)
  }

  func testAPointOrTwoOfReMeasuringIsStillOneDrag() {
    let moved = [move("a", 155, -153), move("b", 157, -151)]
    XCTAssertEqual(PaperProbe.pickup(moved, selected: [], inTouch: true, split: false), .dragged)
    let apart = [move("a", 155, -153), move("b", 158, -153)]
    XCTAssertEqual(PaperProbe.pickup(apart, selected: [], inTouch: true, split: false), .notRigid)
  }

  /// Story 1201, bead context-grabber-vhae: the simulator's drag down on a selected "hello" began on a resize handle
  /// inside the selection, and PaperKit stretched all six strokes (dx -34 to -8, dy 0 to 3). That is a move.
  func testAStretchFromAHandleInsideTheSelectionIsAMove() {
    let keys = (0..<6).map { "t\($0)" }
    let stretched = keys.enumerated().map { move($1, -34 + CGFloat($0) * 5, $0 < 3 ? 0 : 3, resized: true) }
    XCTAssertTrue(PaperProbe.resizeIsMove(stretched, selected: Set(keys), onHandleInside: true))
    // Begun on the handle outside the box: a stretch he meant.
    XCTAssertFalse(PaperProbe.resizeIsMove(stretched, selected: Set(keys), onHandleInside: false))
    // A stroke at the corner it stretched from that kept its place and size (a full stop) leaves it a stretch.
    XCTAssertTrue(PaperProbe.resizeIsMove(Array(stretched.dropLast()), selected: Set(keys), onHandleInside: true))
    // A move PaperKit made as a move is its own.
    let carried = keys.map { move($0, 0, 105) }
    XCTAssertFalse(PaperProbe.resizeIsMove(carried, selected: Set(keys), onHandleInside: true))
    // Something beside the selection changed with it.
    XCTAssertFalse(PaperProbe.resizeIsMove(stretched, selected: Set(keys.dropLast()), onHandleInside: true))
    let resizedOne = keys.enumerated().map { move($1, $0 == 0 ? -34 : 0, 0, resized: $0 == 0) }
    XCTAssertTrue(PaperProbe.resizeIsMove(resizedOne, selected: Set(keys), onHandleInside: true))
    XCTAssertFalse(PaperProbe.resizeIsMove([], selected: [], onHandleInside: true))
  }

  func testAResizeHandleIsKnownByItsClass() {
    XCTAssertTrue(PaperProbe.isResizeHandle("CanvasElementResizeHandle"))
    XCTAssertFalse(PaperProbe.isResizeHandle("CanvasElementResizeView"))
  }
}
