//  Story 650: a kept mark's look a second on, from the numbers `paper_kept_ink` logged on the iPad simulator.

import ContextCore
import XCTest

final class WhiteboardKeptInkTests: XCTestCase {
  private let purple = [186, 57, 230]

  /// context-grabber-qko5: Larry's 12-point label kept whole at Igor's 2.68 pen. The view's purple spans 32 x 9; the strokes
  /// drawn alone touch 34 x 13 but their own purple spans 24 x 6. It read as cut on every look, and was redrawn twice.
  func testASmallLabelDrawnWholeIsWhole() {
    let drawn = KeptInkColours(ink: 33, other: 168, inkWidth: 32, inkHeight: 9)
    let expected = KeptInkColours(ink: 9, inkWidth: 24, inkHeight: 6, allWidth: 34, allHeight: 13)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple))
  }

  /// context-grabber-ikya: a kept text drawn in his purple only up to a tile's edge, 22 px of the 260 a whole one draws.
  func testATextCutAtATileEdgeIsCut() {
    let drawn = KeptInkColours(ink: 22, other: 30, inkWidth: 12, inkHeight: 22)
    let expected = KeptInkColours(ink: 260, inkWidth: 120, inkHeight: 24, allWidth: 124, allHeight: 28)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "cut")
  }

  /// The small label with its right half left blank is still found.
  func testASmallLabelHalfDrawnIsCut() {
    let drawn = KeptInkColours(ink: 16, other: 80, inkWidth: 16, inkHeight: 9)
    let expected = KeptInkColours(ink: 9, inkWidth: 24, inkHeight: 6, allWidth: 34, allHeight: 13)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "cut")
  }

  /// A whole text drawn black past a tile's edge: its purple spans as far, but black the keep added is there.
  func testATileDrawnBlackIsDark() {
    let drawn = KeptInkColours(ink: 200, dark: 60, inkWidth: 120, inkHeight: 24)
    let expected = KeptInkColours(ink: 260, inkWidth: 120, inkHeight: 24, allWidth: 124, allHeight: 28)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "dark")
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 50, ink: purple))
  }

  /// A pen too thin to draw (#883): its strokes alone show none of their colour, so nothing is judged, and it's said so.
  func testAPenTooThinIsNeitherCutNorWhole() {
    let drawn = KeptInkColours()
    let expected = KeptInkColours(allWidth: 34, allHeight: 12)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple))
    XCTAssertTrue(WhiteboardKeptInk.drewNothing(drawn: drawn, expected: expected))
  }

  /// Unread (none of the spot in view) is never cut.
  func testOutOfViewIsNotJudged() {
    let expected = KeptInkColours(ink: 260, inkWidth: 120, inkHeight: 24, allWidth: 124, allHeight: 28)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: .unread, expected: expected, darkBefore: 0, ink: purple))
  }

  /// The view moves a screen away only after a redraw in place left the mark partly drawn, and nothing after that.
  func testTheMoveAwayComesOnlyAfterARedrawInPlace() {
    XCTAssertEqual(WhiteboardKeptInk.heal(afterLook: 0), "readd")
    XCTAssertEqual(WhiteboardKeptInk.heal(afterLook: 1), "scroll")
    XCTAssertNil(WhiteboardKeptInk.heal(afterLook: 2))
  }

  func testTheLookLabelHook() {
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_KEPT_INK_LABEL": "1"]).keptInkLabel)
    XCTAssertFalse(WhiteboardHooks([:]).keptInkLabel)
  }
}
