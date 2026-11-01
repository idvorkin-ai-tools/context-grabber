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

  func testTheThreadIsTitledWithTheDay() throws {
    let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
    XCTAssertEqual(
      WhiteboardFrame.title(at: Date(timeIntervalSince1970: 1_793_534_400), timeZone: utc), "Whiteboard, Nov 1")
  }
}
