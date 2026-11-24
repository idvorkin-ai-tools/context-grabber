import XCTest

@testable import ContextCore

#if canImport(PencilKit)
  import PencilKit
#endif

/// The moment a stroke was made, once for the board: truncated unix ms, as every stroke id and remembered moment was made.
final class BoardMomentTests: XCTestCase {
  func testTruncatesNeverRounds() {
    XCTAssertEqual(BoardMoment.ms(Date(timeIntervalSince1970: 1_795_525_623.1239)), 1_795_525_623_123)
    XCTAssertEqual(BoardMoment.ms(Date(timeIntervalSince1970: 1_795_525_623.9999)), 1_795_525_623_999)
    XCTAssertEqual(BoardMoment.ms(Date(timeIntervalSince1970: 0)), 0)
  }

  /// A kept mark's date is a whole millisecond; one read back a hair under it still names that millisecond when
  /// rounded, where truncation puts it a millisecond early.
  func testNearestHoldsAWholeMillisecondReadBackAHairUnder() {
    let whole = Date(timeIntervalSince1970: Double(1_795_525_623_123) / 1000)
    let hairUnder = Date(timeIntervalSince1970: whole.timeIntervalSince1970 - 1e-6)
    XCTAssertEqual(BoardMoment.nearestMs(whole), 1_795_525_623_123)
    XCTAssertEqual(BoardMoment.nearestMs(hairUnder), 1_795_525_623_123)
    XCTAssertEqual(BoardMoment.ms(hairUnder), 1_795_525_623_122)
    XCTAssertEqual(BoardMoment.nearestMs(Date(timeIntervalSince1970: 1_795_525_623.1236)), 1_795_525_623_124)
  }

  #if canImport(PencilKit)
    func testAStrokeIsKnownByWhenItWasMade() {
      let made = Date(timeIntervalSince1970: 1_795_525_623.5007)
      let point = PKStrokePoint(
        location: .zero, timeOffset: 0, size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: 0
      )
      let stroke = PKStroke(ink: PKInk(.pen), path: PKStrokePath(controlPoints: [point], creationDate: made))
      XCTAssertEqual(BoardMoment.of(stroke), BoardMoment.ms(made))
      XCTAssertEqual(BoardMoment.of(stroke), 1_795_525_623_500)
      XCTAssertEqual(BoardMoment.nearest(stroke), 1_795_525_623_501)
    }
  #endif
}
