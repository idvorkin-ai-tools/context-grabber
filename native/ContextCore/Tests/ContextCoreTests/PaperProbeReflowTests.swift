//  Story 1188 (#1256, #1255): PaperKit's handwriting reflow as the log says it.

import ContextCore
import XCTest

final class PaperProbeReflowTests: XCTestCase {
  func testANotANumberFrameIsTheCrashesFlaw() {
    // The iPad, 2026-11-22: "CALayer position contains NaN: [nan nan]".
    XCTAssertEqual(PaperProbe.reflowFlaw(x: .nan, y: .nan, width: 347, height: 159), .notANumber)
    XCTAssertEqual(PaperProbe.reflowFlaw(x: 0, y: 0, width: .nan, height: 159), .notANumber)
  }

  func testAnEndlessFrameIsAFlaw() {
    // An empty union's frame (CGRect.null) has an endless origin; scaled by zero it becomes not a number.
    XCTAssertEqual(PaperProbe.reflowFlaw(x: .infinity, y: .infinity, width: 0, height: 0), .endless)
    XCTAssertEqual(PaperProbe.reflowFlaw(x: 1, y: -.infinity, width: 4, height: 4), .endless)
  }

  func testAnEmptyFrameIsAFlawAndASoundOneIsNot() {
    XCTAssertEqual(PaperProbe.reflowFlaw(x: 3, y: 4, width: 0, height: 159), .empty)
    XCTAssertNil(PaperProbe.reflowFlaw(x: 153, y: 15, width: 347, height: 159))
  }

  func testTheLogsFrameIsWholePointsAndEmptyWhenNotFinite() {
    XCTAssertEqual(PaperProbe.reflowRect(x: 152.6, y: 15, width: 347.4, height: 159), [153, 15, 347, 159])
    // Never rounded (which traps) nor written (the log's JSON can't carry it): the flaw says it instead.
    XCTAssertEqual(PaperProbe.reflowRect(x: .nan, y: .nan, width: 347, height: 159), [])
    XCTAssertEqual(PaperProbe.reflowRect(x: .infinity, y: 0, width: 0, height: 0), [])
  }

  func testOnlyPaperKitsReflowViewsAreLookedAt() {
    XCTAssertTrue(PaperProbe.isReflowKind("HandwritingReflowView"))
    XCTAssertTrue(PaperProbe.isReflowKind("ReflowTextView"))
    XCTAssertFalse(PaperProbe.isReflowKind("PaperView"))
    XCTAssertFalse(PaperProbe.isReflowKind("PKSelectionGestureView"))
  }

  func testTheEverPresentEmptyContainerIsNotSaid() {
    let container = PaperProbe.ReflowView(
      kind: "HandwritingReflowView", frame: [0, 0, 820, 2120], within: "PaperView", pictures: 0, flawed: [:])
    XCTAssertEqual(PaperProbe.reflowShown([container]), [])
    // The iPad's logs: a ReflowTextView showed while Igor resized or moved handwriting.
    let words = PaperProbe.ReflowView(
      kind: "ReflowTextView", frame: [351, 276, 393, 65], within: "HandwritingReflowView", pictures: 5, flawed: [:])
    XCTAssertEqual(PaperProbe.reflowShown([container, words]), [words])
    var holding = container
    holding.flawed = ["nan": 1]
    XCTAssertEqual(PaperProbe.reflowShown([holding]), [holding])
  }
}
