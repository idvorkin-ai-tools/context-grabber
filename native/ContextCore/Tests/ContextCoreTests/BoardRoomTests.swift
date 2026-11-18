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
    XCTAssertLessThanOrEqual(
      landing.origin.y + size.height, (push?.cut ?? 0) + (push?.dy ?? 0), "clear of the ink pushed")
  }

  func testHiddenInkIsNoObstacle() {
    let strokes = [
      BoardOps.Stroke(ids: ["a"], t: 1, bounds: line(100)),
      BoardOps.Stroke(ids: ["b"], t: 2, bounds: line(200), hidden: true),
    ]
    XCTAssertEqual(BoardOps.shownBoxes(strokes: strokes), [line(100)])
  }

  /// Story 858: room by hand, in whole lines; up closes blank paper only.
  func testRoomByHandOpensWholeLinesAndClosesOnlyBlankPaper() {
    let ink = [line(100), line(300)]
    XCTAssertEqual(BoardRoom.byHand(ink, at: 200, dy: 95), BoardRoom.Push(cut: 200, dy: 80))
    XCTAssertEqual(BoardRoom.byHand(ink, at: 110, dy: 40)?.cut, 100, "at the clear line nearest")
    XCTAssertEqual(BoardRoom.closable(ink, at: 200), 160, "the blank band between, whole lines")
    XCTAssertEqual(BoardRoom.byHand(ink, at: 200, dy: -400), BoardRoom.Push(cut: 200, dy: -160), "never past the ink")
    XCTAssertNil(BoardRoom.byHand(ink, at: 200, dy: 10), "under half a line moves nothing")
    XCTAssertNil(BoardRoom.byHand(ink, at: 400, dy: -80), "nothing below to close up")
  }

  // MARK: #938: Larry's text makes room

  func testATextOnClearPaperMovesNothing() {
    let room = BoardRoom.text(
      CGRect(x: 40, y: 300, width: 200, height: 30), among: [CGRect(x: 40, y: 100, width: 300, height: 30)])
    XCTAssertEqual(room.y, 300)
    XCTAssertNil(room.push)
  }

  func testATextOnALineOpensRoomFromItsTop() {
    // His text's top just inside the line's top: the line and what's below go down clear of it, in whole lines.
    let ink = [CGRect(x: 40, y: 100, width: 300, height: 30), CGRect(x: 40, y: 200, width: 300, height: 30)]
    let room = BoardRoom.text(CGRect(x: 40, y: 105, width: 200, height: 30), among: ink)
    XCTAssertEqual(room.y, 105)
    XCTAssertEqual(room.push, BoardRoom.Push(cut: 100, dy: 80), "100 must go under 135 + 20: two lines")
  }

  func testATextLowInALineLandsUnderIt() {
    let ink = [CGRect(x: 40, y: 100, width: 300, height: 30), CGRect(x: 40, y: 140, width: 300, height: 30)]
    let room = BoardRoom.text(CGRect(x: 40, y: 125, width: 200, height: 30), among: [ink[0], ink[1]])
    XCTAssertEqual(room.y, 140, "just under the line it fell low in")
    XCTAssertEqual(room.push, BoardRoom.Push(cut: 130, dy: 80), "the next line makes way below it")
  }

  func testPlannedTextsPushInkAndLaterGhostsAndEachMakesItsOwnRoom() {
    let strokes = [
      BoardOps.Stroke(ids: ["above"], t: nil, bounds: CGRect(x: 40, y: 400, width: 300, height: 40)),
      BoardOps.Stroke(ids: ["row1"], t: nil, bounds: CGRect(x: 40, y: 578, width: 300, height: 22)),
      BoardOps.Stroke(ids: ["row2"], t: nil, bounds: CGRect(x: 40, y: 618, width: 300, height: 22)),
    ]
    let plan = BoardOps.plan(
      [
        .addText(.init(id: "low", x: 40, y: 900, text: "later", size: 22)),
        .addText(.init(id: "a", x: 40, y: 580, text: "one", size: 22)),
        .addText(.init(id: "b", x: 40, y: 612, text: "two", size: 22)),
      ], strokes: strokes, pages: 1)
    XCTAssertNil(plan.offsets[0], "ink above stays")
    let a = plan.texts.first { $0.id == "a" }
    let b = plan.texts.first { $0.id == "b" }
    XCTAssertEqual(a?.y, 580)
    XCTAssertEqual(b?.y, 612)
    let row1 = strokes[1].bounds.offsetBy(dx: 0, dy: plan.offsets[1]?.dy ?? 0)
    XCTAssertGreaterThan(row1.minY, (b?.box.maxY ?? .infinity), "Igor's row is under his last line")
    XCTAssertEqual(plan.offsets[1], plan.offsets[2], "whole lines, together")
    XCTAssertEqual(
      plan.texts.first { $0.id == "low" }?.y, 900 + (plan.offsets[1]?.dy ?? 0), "his ghost below moved too")
    XCTAssertTrue(plan.changesBoard)
  }

  func testALabelInsideAFrameOnTheBoardMakesNoRoom() {
    let frame = BoardOps.Stroke(ids: ["frame"], t: nil, bounds: CGRect(x: 30, y: 280, width: 400, height: 120))
    let under = BoardOps.Stroke(ids: ["under"], t: nil, bounds: CGRect(x: 30, y: 420, width: 400, height: 30))
    let plan = BoardOps.plan(
      [.addText(.init(id: "in", x: 60, y: 300, text: "inside", size: 22))], strokes: [frame, under], pages: 1)
    XCTAssertTrue(plan.offsets.isEmpty)
    XCTAssertEqual(plan.texts.first?.y, 300)
  }
}
