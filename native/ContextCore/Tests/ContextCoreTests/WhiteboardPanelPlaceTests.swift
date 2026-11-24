import XCTest

@testable import ContextCore

/// Stories 1278, 1279 (#1384): the conversation resizes, and floats as a card or docks.
final class WhiteboardPanelPlaceTests: XCTestCase {
  func testWithNothingStoredThePanelIsAFifthAsBefore() {
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: nil, page: 1000), 200)
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: nil, page: 400), WhiteboardNote.panelFloor)
  }

  func testAStoredHeightIsAShareOfThePageWithinItsBounds() {
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: 0.4, page: 1000), 400)
    XCTAssertEqual(
      WhiteboardPanelPlace.height(stored: 0.95, page: 1000), 1000 * WhiteboardPanelPlace.tallest, "most of the board")
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: 0.01, page: 1000), WhiteboardNote.panelFloor, "about four lines")
  }

  func testDraggingTheGripKeepsAShareOfThePage() {
    let taller = WhiteboardPanelPlace.resized(from: 200, by: 150, page: 1000)
    XCTAssertEqual(taller, 0.35, accuracy: 0.0001)
    XCTAssertEqual(WhiteboardPanelPlace.resized(from: 200, by: 5000, page: 1000), WhiteboardPanelPlace.tallest)
    XCTAssertEqual(WhiteboardPanelPlace.resized(from: 200, by: -5000, page: 1000), 0.12, accuracy: 0.0001)
  }

  func testTheCardStartsTopLeftAndStaysOnTheBoard() {
    let area = (width: 1000.0, height: 800.0)
    let card = WhiteboardPanelPlace.Card.start
    let frame = card.frame(in: area)
    XCTAssertEqual(frame.x, WhiteboardPanelPlace.Card.margin, accuracy: 0.5, "at the left, clear of ? and Feedback")
    XCTAssertEqual(frame.y, WhiteboardPanelPlace.Card.margin, accuracy: 0.5, "at the top")

    let dragged = card.moved(dx: 5000, dy: 5000, in: area).frame(in: area)
    XCTAssertEqual(dragged.x + dragged.width, 1000, accuracy: 0.5, "never off the right edge")
    XCTAssertEqual(dragged.y + dragged.height, 800, accuracy: 0.5, "never off the bottom")
    let back = card.moved(dx: -5000, dy: -5000, in: area).frame(in: area)
    XCTAssertEqual(back.x, 0, accuracy: 0.5)
    XCTAssertEqual(back.y, 0, accuracy: 0.5)
  }

  func testTheCardResizesByItsCornerWithinBounds() {
    let area = (width: 1000.0, height: 800.0)
    let card = WhiteboardPanelPlace.Card.start
    let small = card.resized(dx: -5000, dy: -5000, in: area).frame(in: area)
    XCTAssertEqual(small.width, WhiteboardPanelPlace.Card.narrowest, accuracy: 0.5)
    XCTAssertEqual(small.height, WhiteboardPanelPlace.Card.shortest, accuracy: 0.5)
    let big = card.resized(dx: 5000, dy: 5000, in: area).frame(in: area)
    XCTAssertLessThanOrEqual(big.x + big.width, 1000.5, "the corner stops at the board's edge")
    XCTAssertLessThanOrEqual(big.y + big.height, 800.5)
  }

  func testTheCardIsKeptAsTextAndAnythingElseIsTheStart() {
    let card = WhiteboardPanelPlace.Card(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: card.stored), card)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: ""), .start)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: "nonsense"), .start)
  }
}
