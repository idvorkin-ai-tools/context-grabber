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
    XCTAssertEqual(wide.rect.width * wide.scale, 2048, accuracy: 0.01, "a big board fits 2048 px on its long side")
  }

  func testAnEmptyBoardHasNoPicture() {
    XCTAssertNil(WhiteboardFrame.export(.null))
    XCTAssertNil(WhiteboardFrame.export(.zero))
  }

  // Story 407.
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
}
