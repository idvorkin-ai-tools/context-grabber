import XCTest

@testable import ContextCore

/// The oracle is the board ops spec's *A dragged selection makes room* (stories 973–975): dropped ink stays where it
/// lands, and what is below it slides down by whole lines, as a paste's room does.
final class BoardRoomDropTests: XCTestCase {
  private let line = BoardRoom.line
  private let air = BoardRoom.air

  /// A line of writing across the page, y...y+24.
  private func writing(_ y: CGFloat) -> CGRect { CGRect(x: 80, y: y, width: 500, height: 24) }

  func testDroppedOnClearPaperNothingMoves() {
    let block = CGRect(x: 100, y: 300, width: 200, height: 30)
    XCTAssertNil(BoardRoom.drop(block, among: [writing(100), writing(500)]))
  }

  func testTouchingAnEdgeIsNotSittingOn() {
    let block = CGRect(x: 100, y: 124, width: 200, height: 30)
    XCTAssertNil(BoardRoom.drop(block, among: [writing(100), writing(500)]))
  }

  func testDroppedOnALineTheLineAndAllBelowMoveDownClearOfIt() {
    // Dropped just over the line at 200: its top is on clear paper, so the room opens there.
    let block = CGRect(x: 100, y: 190, width: 200, height: 30)
    let push = try? XCTUnwrap(BoardRoom.drop(block, among: [writing(100), writing(200), writing(300)]))
    XCTAssertEqual(push?.cut, 190, "between the line above and the one it sits on")
    let dy = push?.dy ?? 0
    XCTAssertEqual(dy.truncatingRemainder(dividingBy: line), 0, "whole lines")
    XCTAssertGreaterThanOrEqual(200 + dy, block.maxY + air, "the line it sat on is now under it, with air")
    XCTAssertLessThan(200 + dy - line, block.maxY + air, "and no further than it needs")
  }

  func testInkAboveTheCutStays() {
    let block = CGRect(x: 100, y: 190, width: 200, height: 30)
    let push = BoardRoom.drop(block, among: [writing(100), writing(200)])
    XCTAssertGreaterThan(push?.cut ?? 0, writing(100).maxY - 1, "the line above is above the cut")
  }

  func testDroppedLowOnALineThatStartsAboveItTheCutIsUnderThatLine() {
    // The block's top falls near the bottom of the line at 200: that line stays, the one below moves.
    let block = CGRect(x: 100, y: 220, width: 200, height: 40)
    let push = BoardRoom.drop(block, among: [writing(200), writing(250)])
    XCTAssertEqual(push?.cut, 224)
    XCTAssertGreaterThanOrEqual(250 + (push?.dy ?? 0), block.maxY + air)
  }
}
