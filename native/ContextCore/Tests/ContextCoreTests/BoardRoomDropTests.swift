import XCTest

@testable import ContextCore

/// The oracle is the board ops spec's *Dropping ink onto writing makes room* (stories 973–975): dropped ink stays
/// where it lands, and what is below it slides down by whole lines, as a paste's room does.
final class BoardRoomDropTests: XCTestCase {
  private let line = BoardRoom.line
  private let air = BoardRoom.air

  /// Where the dragged ink was lifted from: clear paper well below every line here.
  private let lifted = CGRect(x: 100, y: 900, width: 200, height: 30)

  /// A line of writing across the page, y...y+24.
  private func writing(_ y: CGFloat) -> CGRect { CGRect(x: 80, y: y, width: 500, height: 24) }

  func testDroppedOnClearPaperNothingMoves() {
    let block = CGRect(x: 100, y: 300, width: 200, height: 30)
    XCTAssertNil(BoardRoom.drop(block, from: lifted, among: [writing(100), writing(500)]))
  }

  func testTouchingAnEdgeIsNotSittingOn() {
    let block = CGRect(x: 100, y: 124, width: 200, height: 30)
    XCTAssertNil(BoardRoom.drop(block, from: lifted, among: [writing(100), writing(500)]))
  }

  func testDroppedOnALineTheLineAndAllBelowMoveDownClearOfIt() {
    // Dropped just over the line at 200: its top is on clear paper, so the room opens there.
    let block = CGRect(x: 100, y: 190, width: 200, height: 30)
    let push = try? XCTUnwrap(BoardRoom.drop(block, from: lifted, among: [writing(100), writing(200), writing(300)]))
    XCTAssertEqual(push?.cut, 190, "between the line above and the one it sits on")
    let dy = push?.dy ?? 0
    XCTAssertEqual(dy.truncatingRemainder(dividingBy: line), 0, "whole lines")
    XCTAssertGreaterThanOrEqual(200 + dy, block.maxY + air, "the line it sat on is now under it, with air")
    XCTAssertLessThan(200 + dy - line, block.maxY + air, "and no further than it needs")
  }

  func testInkAboveTheCutStays() {
    let block = CGRect(x: 100, y: 190, width: 200, height: 30)
    let push = BoardRoom.drop(block, from: lifted, among: [writing(100), writing(200)])
    XCTAssertGreaterThan(push?.cut ?? 0, writing(100).maxY - 1, "the line above is above the cut")
  }

  func testDroppedLowOnALineThatStartsAboveItTheCutIsUnderThatLine() {
    // The block's top falls near the bottom of the line at 200: that line stays, the one below moves.
    let block = CGRect(x: 100, y: 220, width: 200, height: 40)
    let push = BoardRoom.drop(block, from: lifted, among: [writing(200), writing(250)])
    XCTAssertEqual(push?.cut, 224)
    XCTAssertGreaterThanOrEqual(250 + (push?.dy ?? 0), block.maxY + air)
  }

  func testAWordSlidAlongItsOwnLineOntoItsNeighbourMovesNothing() {
    // Story 969: lifted from the line at 200 and dropped on a word beside it, still on that line.
    let from = CGRect(x: 100, y: 202, width: 60, height: 20)
    let block = from.offsetBy(dx: 120, dy: 0)
    let neighbour = CGRect(x: 200, y: 200, width: 120, height: 24)
    XCTAssertNil(BoardRoom.drop(block, from: from, among: [writing(100), neighbour, writing(300)]))
  }

  /// Story 1172, from the iPad's log of 2026-11-22 (board ead78e80): Larry's kept text, lifted from below, dropped on
  /// Igor's first line. His two lines go down together, clear of it, by whole lines.
  func testAKeptTextDroppedOnHisWritingPushesItDown() {
    let from = CGRect(x: 34, y: 223, width: 248, height: 25)
    let block = CGRect(x: 111, y: 67, width: 248, height: 25)
    let first = CGRect(x: 23, y: 54, width: 503, height: 41)
    let second = CGRect(x: 23, y: 97, width: 108, height: 27)
    let push = try? XCTUnwrap(BoardRoom.drop(block, from: from, among: [first, second]))
    XCTAssertEqual(push?.cut, first.minY, "between lines: above his first line, not through it")
    let dy = push?.dy ?? 0
    XCTAssertEqual(dy.truncatingRemainder(dividingBy: line), 0, "whole lines")
    XCTAssertGreaterThanOrEqual(first.minY + dy, block.maxY + air, "his first line now sits under it, with air")
  }

  func testAWordDraggedFromItsLineOntoTheNextPushesIt() {
    let from = CGRect(x: 100, y: 202, width: 60, height: 20)
    let block = from.offsetBy(dx: 0, dy: 100)
    let push = BoardRoom.drop(block, from: from, among: [CGRect(x: 200, y: 200, width: 120, height: 24), writing(300)])
    XCTAssertNotNil(push, "the line it landed on is another line")
  }
}
