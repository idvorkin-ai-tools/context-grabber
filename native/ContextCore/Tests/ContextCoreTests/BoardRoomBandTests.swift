//  Stories 1044–1046 (#1000): the band the room handle shows while held is what the lift will do.

import ContextCore
import CoreGraphics
import XCTest

final class BoardRoomBandTests: XCTestCase {
  private func line(_ y: CGFloat) -> CGRect { CGRect(x: 40, y: y, width: 300, height: 30) }

  func testTheBandShowsTheMomentTheHoldFires() {
    let band = BoardRoomBand.held([line(100), line(300)], at: 200, dy: 0)
    XCTAssertEqual(band, BoardRoomBand(cut: 200, dy: 0, kind: .opening))
    XCTAssertEqual(band.label, "Making room")
    XCTAssertEqual(band.height, 0, "a thin line before half a line's drag")
  }

  func testDraggedDownTheBandIsTheRoomTheLiftOpens() {
    let ink = [line(100), line(300)]
    let band = BoardRoomBand.held(ink, at: 200, dy: 95)
    XCTAssertEqual(band.cut, BoardRoom.byHand(ink, at: 200, dy: 95)?.cut)
    XCTAssertEqual(band.dy, 80, "whole lines, as the lift")
    XCTAssertEqual(band.top, 200)
    XCTAssertEqual(band.lines, 2)
    XCTAssertEqual(band.kind, .opening)
    XCTAssertEqual(BoardRoomBand.held(ink, at: 110, dy: 40).cut, 100, "at the clear line nearest, as the lift")
  }

  func testDraggedUpTheBandCoversTheBlankPaperThatCloses() {
    let band = BoardRoomBand.held([line(100), line(300)], at: 200, dy: -400)
    XCTAssertEqual(band.kind, .closing)
    XCTAssertEqual(band.label, "Closing room")
    XCTAssertEqual(band.dy, -160, "never past the ink above")
    XCTAssertEqual(band.top, 40, "above the cut")
    XCTAssertEqual(band.height, 160)
  }

  func testDraggedUpWithNoBlankPaperItSaysSo() {
    let band = BoardRoomBand.held([line(100), line(140)], at: 135, dy: -80)
    XCTAssertEqual(band.kind, .nothingToClose)
    XCTAssertEqual(band.label, "No blank paper to close")
    XCTAssertEqual(band.height, 0)
    XCTAssertEqual(BoardRoomBand.held([line(100), line(300)], at: 200, dy: -10).kind, .opening, "under half a line")
  }
}
