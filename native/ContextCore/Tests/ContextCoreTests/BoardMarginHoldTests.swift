import XCTest

@testable import ContextCore

/// Stories 930–933: a Pencil in the margin is the handle once it has held still; a Pencil that moves first draws; and
/// every try has its verdict for the log.
final class BoardMarginHoldTests: XCTestCase {
  private func path(_ points: [(CGFloat, CGFloat, Double)]) -> [(point: CGPoint, time: Double)] {
    points.map { (point: CGPoint(x: $0.0, y: $0.1), time: $0.2) }
  }

  func testAPencilHeldStillInTheMarginThenDraggedIsTheHandle() {
    let held = path([(30, 200, 0), (31, 201, 0.2), (32, 203, 0.55), (32, 260, 0.8), (33, 282, 1.0)])
    XCTAssertEqual(BoardMarginHold.pencil(held), .hold(dy: 82))
    XCTAssertTrue(BoardMarginHold.pencil(held).opensRoom)
  }

  func testAPencilHeldStillAndLiftedIsTheMenu() {
    let still = path([(30, 200, 0), (33, 204, 0.3), (31, 202, 0.6)])
    XCTAssertEqual(BoardMarginHold.pencil(still), .hold(dy: 2))
    XCTAssertFalse(BoardMarginHold.pencil(still).opensRoom, "under half a line: the menu")
  }

  /// His strokes on the iPad: dragged down at once, 150–400 ms.
  func testAPencilThatMovesFirstDraws() {
    let quick = path([(32, 500, 0), (33, 506, 0.05), (36, 517, 0.15)])
    XCTAssertEqual(BoardMarginHold.pencil(quick), .moved(after: 0.15, by: hypot(4, 17)))
    XCTAssertEqual(BoardMarginHold.pencil(quick).reason, "moved")
    XCTAssertFalse(BoardMarginHold.pencil(quick).opensRoom)
  }

  func testAPencilLiftedTooSoonOrOutsideTheMarginIsNoHold() {
    XCTAssertEqual(BoardMarginHold.pencil(path([(30, 200, 0), (31, 200, 0.3)])), .tooShort(seconds: 0.3))
    XCTAssertEqual(BoardMarginHold.pencil(path([(80, 200, 0), (80, 200, 0.8)])), .notInMargin)
    XCTAssertEqual(BoardMarginHold.pencil([]), .notInMargin)
  }

  func testAFingersTryIsJudgedForTheLog() {
    XCTAssertEqual(BoardMarginHold.finger(seconds: 0.7, travel: 3, recognized: true), "hold")
    XCTAssertEqual(BoardMarginHold.finger(seconds: 0.7, travel: 30, recognized: false), "moved")
    XCTAssertEqual(BoardMarginHold.finger(seconds: 0.2, travel: 2, recognized: false), "too_short")
    XCTAssertEqual(BoardMarginHold.finger(seconds: 0.8, travel: 2, recognized: false), "not_seen", "PaperKit took it")
  }
}
