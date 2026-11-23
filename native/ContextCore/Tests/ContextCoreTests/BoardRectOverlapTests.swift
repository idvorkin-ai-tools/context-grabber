import XCTest

@testable import ContextCore

/// Story 1511: the board's rules ask whether two boxes overlap the way CoreGraphics answers `intersects`, so the
/// iPad, the Mac, Linux and the Cockpit's WebAssembly build land a paste in the same spot. The cases are the ones
/// checked against Apple's `CGRect.intersects` on the Mac (macOS 27 SDK, 2026-11-23); swift-corelibs-foundation
/// answers the first two the other way.
final class BoardRectOverlapTests: XCTestCase {
  private let a = CGRect(x: 0, y: 0, width: 10, height: 10)

  func testAnEdgeOrACornerSharedIsNoOverlap() {
    XCTAssertFalse(a.overlaps(CGRect(x: 10, y: 0, width: 10, height: 10)))
    XCTAssertFalse(a.overlaps(CGRect(x: 0, y: 10, width: 10, height: 10)))
    XCTAssertFalse(a.overlaps(CGRect(x: 10, y: 10, width: 10, height: 10)))
  }

  func testAnyAreaIsAnOverlap() {
    XCTAssertTrue(a.overlaps(CGRect(x: 9.999, y: 0, width: 10, height: 10)))
    XCTAssertTrue(a.overlaps(CGRect(x: 2, y: 2, width: 3, height: 3)))
  }

  func testABoxWithNoWidthMeetsWhatHoldsItButNotWhatItOnlyTouches() {
    XCTAssertTrue(a.overlaps(CGRect(x: 5, y: 0, width: 0, height: 10)))
    XCTAssertFalse(a.overlaps(CGRect(x: 10, y: 0, width: 0, height: 10)))
    XCTAssertFalse(a.overlaps(.null))
  }

  /// A paste whose air only touches a line of writing's box lands there: the grid spot at 84 sits exactly under the
  /// line's air (60 + 20 = 80 at the bottom; the block's top is the view's 60 plus 20 of air), so it is clear.
  func testAPasteMayLandWhereItOnlyTouchesWritingsAir() {
    let ink = [CGRect(x: 100, y: 30, width: 600, height: 30)]
    let landing = BoardRoom.place(
      CGSize(width: 100, height: 40), view: CGRect(x: 0, y: 60, width: 820, height: 100), ink: ink)
    XCTAssertNil(landing.push)
    XCTAssertEqual(landing.origin.y, 80)
  }
}
