import XCTest

@testable import ContextCore

/// Story 852: a paste lands clear of ink, or opens room by the web board's rules.
final class BoardRoomTests: XCTestCase {
  private let view = CGRect(x: 0, y: 0, width: 820, height: 1000)
  private func line(_ y: CGFloat, x: CGFloat = 100, w: CGFloat = 600) -> CGRect {
    CGRect(x: x, y: y, width: w, height: 30)
  }

  func testRowsMergeWhatOverlapsAndACutLandsOnAClearLine() {
    let ink = [line(100), CGRect(x: 300, y: 120, width: 50, height: 30), line(300)]
    XCTAssertEqual(BoardRoom.rows(ink), [100...150, 300...330])
    XCTAssertEqual(BoardRoom.cut(ink, at: 200), 200, "a clear line is itself")
    XCTAssertEqual(BoardRoom.cut(ink, at: 110), 100, "nearer the top: the top")
    XCTAssertEqual(BoardRoom.cut(ink, at: 140), 150, "nearer the bottom: the bottom")
    let tall = [CGRect(x: 100, y: 0, width: 100, height: 400)]
    XCTAssertEqual(BoardRoom.cut(tall, at: 150), 400, "the top only within a cut's reach")
    let band = BoardRoom.band(ink, at: 200)
    XCTAssertEqual(band.above, 150)
    XCTAssertEqual(band.below, 300)
    XCTAssertNil(BoardRoom.band(ink, at: 400).below)
  }

  func testAPasteOnAnEmptyViewLandsInItsMiddle() {
    let landing = BoardRoom.place(CGSize(width: 200, height: 60), view: view, ink: [])
    XCTAssertNil(landing.push)
    XCTAssertEqual(landing.origin.x + 100, view.midX, accuracy: 20)
    XCTAssertEqual(landing.origin.y + 30, view.midY, accuracy: 20)
  }

  func testAPasteFindsTheClearPatchNearestTheMiddleAndNeverTouchesInk() {
    let ink = [CGRect(x: 64, y: 400, width: 756, height: 200)]
    let size = CGSize(width: 300, height: 80)
    let landing = BoardRoom.place(size, view: view, ink: ink)
    XCTAssertNil(landing.push)
    let box = CGRect(origin: landing.origin, size: size)
    XCTAssertFalse(box.intersects(ink[0].insetBy(dx: -BoardRoom.air, dy: -BoardRoom.air)), "\(box)")
    XCTAssertGreaterThanOrEqual(box.minX, BoardMargin.width + BoardRoom.air, "right of the margin")
  }

  func testAFullViewOpensRoomAtTheClearLineNearestTheMiddle() {
    // Lines every 60 points down the whole view: no patch holds a 100-point block.
    let ink = stride(from: CGFloat(10), to: 1000, by: 60).map { line($0, x: 64, w: 756) }
    let size = CGSize(width: 300, height: 100)
    let landing = BoardRoom.place(size, view: view, ink: ink)
    let push = try? XCTUnwrap(landing.push)
    XCTAssertEqual(push?.cut, BoardRoom.cut(ink, at: 500))
    // The band at the cut is 30 points; the block needs 140 with its air: 110 more, three whole lines.
    XCTAssertEqual(push?.dy, 120)
    let (above, _) = BoardRoom.band(ink, at: push?.cut ?? 0)
    XCTAssertEqual(landing.origin, CGPoint(x: BoardMargin.width + BoardRoom.air, y: above + BoardRoom.air))
    XCTAssertLessThanOrEqual(landing.origin.y + size.height, (push?.cut ?? 0) + (push?.dy ?? 0), "clear of the ink pushed")
  }

  func testHiddenInkIsNoObstacle() {
    let strokes = [
      BoardOps.Stroke(ids: ["a"], t: 1, bounds: line(100)),
      BoardOps.Stroke(ids: ["b"], t: 2, bounds: line(200), hidden: true),
    ]
    XCTAssertEqual(BoardOps.shownBoxes(strokes: strokes), [line(100)])
  }
}
