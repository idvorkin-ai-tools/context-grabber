import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class WhiteboardFrameTests: XCTestCase {
  func testLarrysPictureHasAMarginAndStaysSharpButSmall() throws {
    let small = try XCTUnwrap(WhiteboardFrame.export(CGRect(x: 100, y: 100, width: 200, height: 100)))
    XCTAssertEqual(small.rect, CGRect(x: 60, y: 60, width: 280, height: 180))
    XCTAssertEqual(small.scale, 2, "a small sketch is drawn at the screen's own 2x")
    let wide = try XCTUnwrap(WhiteboardFrame.export(CGRect(x: 0, y: 0, width: 4_016, height: 500)))
    XCTAssertEqual(
      wide.rect.width * wide.scale * wide.rect.height * wide.scale, 2048 * 2048, accuracy: 1,
      "a big board spends the 2048 x 2048 budget on its own shape")
    XCTAssertEqual(wide.rect.width * wide.scale, 5442.5, accuracy: 1, "so a wide one is wider than 2048 px")
    let square = try XCTUnwrap(WhiteboardFrame.export(CGRect(x: 0, y: 0, width: 1_960, height: 1_960)))
    XCTAssertEqual(square.rect.width * square.scale, 2048, accuracy: 0.01, "a square board is 2048 px as before")
  }

  // Story 420: the Nov 2 board, 1179 x 9759 points, went out as 248 x 2048 px with the handwriting five pixels high.
  func testATallColumnOfNotesIsNotShrunkToASliver() throws {
    let tall = try XCTUnwrap(WhiteboardFrame.export(CGRect(x: 9_460, y: 126, width: 1_099, height: 9_679)))
    XCTAssertEqual(tall.rect.width * tall.scale, 711.8, accuracy: 1)
    XCTAssertEqual(tall.rect.height * tall.scale, 5892.2, accuracy: 1)
    XCTAssertGreaterThan(tall.scale, 0.6, "30-point handwriting is 18 px, not 6")
    // A board taller than the APIs take whole stops at the long side's cap instead.
    let huge = try XCTUnwrap(WhiteboardFrame.export(CGRect(x: 0, y: 0, width: 100, height: 20_000)))
    XCTAssertEqual(huge.rect.height * huge.scale, WhiteboardFrame.maxLong, accuracy: 0.01)
  }

  func testAnEmptyBoardHasNoPicture() {
    XCTAssertNil(WhiteboardFrame.export(.null))
    XCTAssertNil(WhiteboardFrame.export(.zero))
  }

  // Stories 414, 415: the board points between lines at each zoom, which the grid and the ruled lines on paper share.
  func testTheGridDoublesItsStepOnlyWhenLinesWouldCrowd() {
    let worked: [(zoom: CGFloat, gap: CGFloat)] = [
      (3, 120), (1, 40), (0.75, 30), (0.7, 28),
      (0.55, 44), (0.5, 40),
      (0.25, 40),
      (0.1, 32),
    ]
    for (zoom, gap) in worked {
      XCTAssertEqual(WhiteboardFrame.lineStep(zoom: zoom) * zoom, gap, accuracy: 0.0001, "zoom \(zoom)")
    }
  }

  // Story 415: the lines stay apart on screen at any zoom, and every line left is a line of the finest grid, so
  // pinching out only ever removes lines.
  func testGridLinesStayApartAtAnyZoomAndKeepOnlyLinesThatWereThere() {
    for zoom in stride(from: CGFloat(0.1), through: 3, by: 0.05) {
      let step = WhiteboardFrame.lineStep(zoom: zoom)
      XCTAssertGreaterThanOrEqual(step * zoom, WhiteboardFrame.gridMinGap, "zoom \(zoom)")
      XCTAssertEqual(step / WhiteboardFrame.gridStep, (step / WhiteboardFrame.gridStep).rounded(), accuracy: 0.0001)
    }
  }

  // #624: the board's ink below a line moved down 173 points in one go.
  func testStrokesMovedNamesTheShiftAndTheLineItStartedFrom() throws {
    let above = CGRect(x: 10, y: 100, width: 50, height: 20)
    let below = CGRect(x: 10, y: 300, width: 50, height: 20)
    let lowest = CGRect(x: 90, y: 900, width: 50, height: 20)
    let moved = try XCTUnwrap(
      WhiteboardFrame.strokesMoved(
        before: [above, below, lowest],
        after: [above, below.offsetBy(dx: 0, dy: 173), lowest.offsetBy(dx: 0, dy: 173)]))
    XCTAssertEqual(moved.count, 2)
    XCTAssertEqual(moved.dx, 0)
    XCTAssertEqual(moved.dy, 173)
    XCTAssertEqual(moved.topY, 300)
  }

  func testStrokesMovedIsNilWhenNothingMovedOrAStrokeCameOrWent() {
    let box = CGRect(x: 10, y: 100, width: 50, height: 20)
    XCTAssertNil(WhiteboardFrame.strokesMoved(before: [box], after: [box]))
    XCTAssertNil(WhiteboardFrame.strokesMoved(before: [box], after: [box, box.offsetBy(dx: 0, dy: 5)]))
  }
}
