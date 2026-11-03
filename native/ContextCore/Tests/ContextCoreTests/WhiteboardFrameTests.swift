import CoreGraphics
import XCTest

@testable import ContextCore

final class WhiteboardFrameTests: XCTestCase {
  let iPad = CGSize(width: 1000, height: 800)

  func testAnEmptyBoardOpensOnItsMiddle() {
    let o = WhiteboardFrame.openingOffset(drawing: nil, viewport: iPad)
    XCTAssertEqual(o, CGPoint(x: 9_500, y: 9_600))
    XCTAssertEqual(WhiteboardFrame.openingOffset(drawing: .null, viewport: iPad), o)
  }

  func testADrawingOpensCentredOnIt() {
    let o = WhiteboardFrame.openingOffset(drawing: CGRect(x: 12_000, y: 3_000, width: 400, height: 200), viewport: iPad)
    XCTAssertEqual(o, CGPoint(x: 11_700, y: 2_700))
  }

  func testTheViewNeverOpensOffTheBoard() {
    let corner = WhiteboardFrame.openingOffset(drawing: CGRect(x: 10, y: 19_990, width: 5, height: 5), viewport: iPad)
    XCTAssertEqual(corner, CGPoint(x: 0, y: 19_200))
  }

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

  // Stories 414, 415.
  func testTheGridDoublesItsStepOnlyWhenLinesWouldCrowd() {
    let worked: [(zoom: CGFloat, gap: CGFloat)] = [
      (3, 120), (1, 40), (0.75, 30), (0.7, 28),
      (0.55, 44), (0.5, 40),
      (0.25, 40),
      (0.1, 32),
    ]
    for (zoom, gap) in worked {
      let grid = WhiteboardFrame.grid(offset: .zero, viewport: iPad, zoom: zoom)
      XCTAssertEqual(grid.gap, gap, accuracy: 0.0001, "zoom \(zoom)")
    }
  }

  // Story 415: at half size the lines left are every 80 board points, 2_000 and 1_440 here.
  func testAThinnedGridKeepsOnlyLinesOfTheCoarserStep() {
    let grid = WhiteboardFrame.grid(offset: CGPoint(x: 1_030, y: 755), viewport: iPad, zoom: 0.5)
    XCTAssertEqual(grid.origin, CGPoint(x: 1_000, y: 720))
  }

  // Story 415.
  func testGridLinesStayApartAndFewAtAnyZoom() {
    let viewport = CGSize(width: 1366, height: 1024)
    for zoom in stride(from: CGFloat(0.1), through: 3, by: 0.05) {
      let grid = WhiteboardFrame.grid(offset: .zero, viewport: viewport, zoom: zoom)
      XCTAssertGreaterThanOrEqual(grid.gap, WhiteboardFrame.gridMinGap)
      XCTAssertLessThanOrEqual(grid.across + grid.down, 106, "zoom \(zoom)")
      // Every line is a line of the finest grid, so pinching only ever removes lines.
      let step = grid.gap / zoom / WhiteboardFrame.gridStep
      XCTAssertEqual(step, step.rounded(), accuracy: 0.0001)
    }
  }

  // Story 413.
  func testTheGridCoversTheViewportAndHoldsStillBetweenLines() {
    let viewport = CGSize(width: 800, height: 600)
    let grid = WhiteboardFrame.grid(offset: CGPoint(x: 10_010, y: 7_205), viewport: viewport, zoom: 1)
    XCTAssertEqual(grid.origin, CGPoint(x: 10_000, y: 7_200))
    XCTAssertLessThanOrEqual(grid.origin.x, 10_010)
    XCTAssertGreaterThanOrEqual(grid.origin.x + CGFloat(grid.across - 1) * grid.gap, 10_010 + viewport.width)
    XCTAssertGreaterThanOrEqual(grid.origin.y + CGFloat(grid.down - 1) * grid.gap, 7_205 + viewport.height)
    XCTAssertEqual(grid, WhiteboardFrame.grid(offset: CGPoint(x: 10_030, y: 7_230), viewport: viewport, zoom: 1))
    XCTAssertNotEqual(grid, WhiteboardFrame.grid(offset: CGPoint(x: 10_040, y: 7_230), viewport: viewport, zoom: 1))
  }

  func testTheGridCoversABounceOffTheBoard() {
    let grid = WhiteboardFrame.grid(offset: CGPoint(x: -30, y: -30), viewport: CGSize(width: 400, height: 400), zoom: 1)
    XCTAssertLessThanOrEqual(grid.origin.x, -30)
    XCTAssertLessThanOrEqual(grid.origin.y, -30)
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
