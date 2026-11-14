import Foundation
import XCTest

@testable import ContextCore

/// Story 821 (#907): how a full-size chat picture zooms, pans and when a swipe still closes it.
final class ChatImageZoomTests: XCTestCase {
  func testAPinchStaysBetweenHalfAndFiveTimesAndSettlesBetweenOneAndFive() {
    XCTAssertEqual(ChatImageZoom.pinching(3), 3)
    XCTAssertEqual(ChatImageZoom.pinching(9), 5, "never past five times")
    XCTAssertEqual(ChatImageZoom.pinching(0.7), 0.7, "a pinch closed past fitted shows smaller while held")
    XCTAssertEqual(ChatImageZoom.pinching(0.1), 0.5, "but never vanishes")
    XCTAssertEqual(ChatImageZoom.settled(0.7), 1, "let go smaller than fitted, it settles to fitted")
    XCTAssertEqual(ChatImageZoom.settled(2.2), 2.2)
    XCTAssertEqual(ChatImageZoom.settled(7), 5)
  }

  func testADoubleTapGoesFromFittedToTwoAndAHalfAndBack() {
    XCTAssertEqual(ChatImageZoom.doubleTapped(1), 2.5)
    XCTAssertEqual(ChatImageZoom.doubleTapped(2.5), 1)
    XCTAssertEqual(ChatImageZoom.doubleTapped(4), 1, "any zoom goes back to fitted")
  }

  func testTheFittedSizeKeepsThePicturesShape() {
    let screen = CGSize(width: 400, height: 800)
    XCTAssertEqual(ChatImageZoom.fitted(CGSize(width: 1000, height: 500), in: screen), CGSize(width: 400, height: 200))
    XCTAssertEqual(ChatImageZoom.fitted(CGSize(width: 100, height: 400), in: screen), CGSize(width: 200, height: 800))
    XCTAssertEqual(ChatImageZoom.fitted(.zero, in: screen), .zero, "a picture with no size has none")
  }

  func testAPanStopsAtTheEdgeOfTheZoomedPicture() {
    let screen = CGSize(width: 400, height: 800)
    let picture = CGSize(width: 400, height: 200)
    // At twice, the picture is 800 by 400: 200 points spare each side, none up or down (it is shorter than the screen).
    XCTAssertEqual(
      ChatImageZoom.clamped(CGSize(width: 150, height: 90), scale: 2, picture: picture, in: screen),
      CGSize(width: 150, height: 0))
    XCTAssertEqual(
      ChatImageZoom.clamped(CGSize(width: -900, height: 0), scale: 2, picture: picture, in: screen),
      CGSize(width: -200, height: 0))
    // At five, 2000 by 1000: 800 spare each side and 100 up and down.
    XCTAssertEqual(
      ChatImageZoom.clamped(CGSize(width: 900, height: -300), scale: 5, picture: picture, in: screen),
      CGSize(width: 800, height: -100))
    XCTAssertEqual(
      ChatImageZoom.clamped(CGSize(width: 50, height: 50), scale: 1, picture: picture, in: screen), .zero,
      "fitted, it stays centred")
  }

  func testZoomingKeepsThePointUnderTheFingersStill() {
    // From fitted and centred, twice around a point 100 right of the centre: that point stays 100 right.
    XCTAssertEqual(
      ChatImageZoom.anchored(.zero, around: CGPoint(x: 100, y: 0), from: 1, to: 2), CGSize(width: -100, height: 0))
    // Already panned: the same rule from where it is.
    XCTAssertEqual(
      ChatImageZoom.anchored(CGSize(width: -100, height: 20), around: CGPoint(x: 0, y: 40), from: 2, to: 4),
      CGSize(width: -200, height: 0))
    XCTAssertEqual(
      ChatImageZoom.anchored(CGSize(width: 5, height: 5), around: .zero, from: 0, to: 2), CGSize(width: 5, height: 5))
  }

  func testASwipeClosesOnlyAFittedPicture() {
    XCTAssertTrue(ChatImageClose.closes(dragHeight: 200, scale: 1))
    XCTAssertFalse(ChatImageClose.closes(dragHeight: 200, scale: 1.5), "zoomed, a drag pans")
    XCTAssertFalse(ChatImageClose.closes(dragHeight: 40, scale: 1), "a short one still leaves it")
  }

  func testTheLoggedScaleIsRoundedToTwoPlaces() {
    XCTAssertEqual(ChatImageZoom.logged(2.34567), 2.35)
    XCTAssertEqual(ChatImageZoom.logged(1), 1)
  }
}
