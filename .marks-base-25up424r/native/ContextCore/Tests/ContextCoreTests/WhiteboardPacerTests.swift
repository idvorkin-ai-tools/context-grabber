import XCTest

@testable import ContextCore

/// The oracle is the spec's "Only one turn is asked at a time; strokes made meanwhile get their own turn after the next
/// pause", story 359, and "an answer that lands while he draws still shows".
final class WhiteboardPacerTests: XCTestCase {
  /// A turn in flight, the state every story here starts from.
  private func asking() -> WhiteboardPacer {
    var pacer = WhiteboardPacer()
    pacer.strokeAdded()
    XCTAssertTrue(pacer.pauseEnded())
    pacer.turnStarted()
    return pacer
  }

  func testAPauseWithNoTurnOnItsWayAsksAndNothingFollows() {
    var pacer = asking()
    XCTAssertFalse(pacer.turnLanded())
  }

  func testAStrokeDuringATurnAsksAgainOnlyAfterItLandsAndAFreshPause() {
    var pacer = asking()
    pacer.strokeAdded()
    XCTAssertFalse(pacer.pauseEnded(), "only one turn at a time")
    XCTAssertTrue(pacer.turnLanded(), "the stroke's pause starts over")
    XCTAssertTrue(pacer.pauseEnded())
    pacer.turnStarted()
    XCTAssertFalse(pacer.turnLanded(), "the owed ask was paid once")
  }

  func testAStrokeAfterADismissalStillGetsItsAskWhenTheOldTurnLands() {
    var pacer = asking()
    pacer.dropped()
    pacer.strokeAdded()
    XCTAssertFalse(pacer.pauseEnded())
    XCTAssertTrue(pacer.turnLanded())
  }

  func testADismissalForgetsAnAskOwedBeforeIt() {
    var pacer = asking()
    pacer.strokeAdded()
    XCTAssertFalse(pacer.pauseEnded())
    pacer.dropped()
    XCTAssertFalse(pacer.turnLanded())
  }

  func testATurnLandingWhileTheToolIsDownWaitsForTheLift() {
    var pacer = asking()
    pacer.strokeAdded()
    XCTAssertFalse(pacer.pauseEnded())
    pacer.toolWentDown()
    XCTAssertFalse(pacer.turnLanded(), "never asked mid-stroke")
    XCTAssertTrue(pacer.toolLifted())
    XCTAssertFalse(pacer.toolLifted(), "one lift, one pause")
  }

  func testATouchDownRestartsAPauseAtTheLiftEvenIfTheToolAddsNoStroke() {
    var pacer = WhiteboardPacer()
    pacer.strokeAdded()
    pacer.toolWentDown()
    XCTAssertTrue(pacer.toolLifted(), "an eraser's touch must not lose the stroke before it")
    XCTAssertTrue(pacer.pauseEnded())
  }

  func testALiftWithNoPauseOrAskOwedStartsNothing() {
    var pacer = WhiteboardPacer()
    pacer.toolWentDown()
    XCTAssertFalse(pacer.toolLifted())
  }

  func testADismissalWhileTheToolIsDownForgetsThePause() {
    var pacer = WhiteboardPacer()
    pacer.strokeAdded()
    pacer.toolWentDown()
    pacer.dropped()
    XCTAssertFalse(pacer.toolLifted())
  }

  func testDrawingLeavesAnAnswerFreshAndADismissalMakesItStale() {
    var pacer = asking()
    let asked = pacer.generation
    pacer.strokeAdded()
    pacer.toolWentDown()
    XCTAssertTrue(pacer.toolLifted())
    XCTAssertEqual(pacer.generation, asked, "an answer landing during drawing still shows")
    pacer.dropped()
    XCTAssertNotEqual(pacer.generation, asked)
  }
}
