import Foundation
import XCTest

@testable import ContextCore

/// Story 662: Larry's turn on a board, one at a time, latest wins.
final class WhiteboardLarryTurnTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  func testAPauseWhileIdleSends() {
    var turn = WhiteboardLarryTurn()
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.paused(version: 1, words: nil, now: at(0)), .send(words: nil))
    XCTAssertTrue(turn.looking)
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 1))
  }

  func testAPauseWhileATurnIsOutSendsNothing() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(5)), .held)
    XCTAssertEqual(turn.paused(version: 4, words: nil, now: at(9)), .held)
    XCTAssertEqual(turn.latest, 4, "the newest version is remembered")
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 1), "still the first turn")
  }

  func testHisAnswerWithTheBoardMovedOnSendsOnce() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: nil, now: at(5))
    _ = turn.paused(version: 3, words: nil, now: at(8))
    XCTAssertEqual(turn.replied(version: 3, now: at(70)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(70), sent: 3))
    XCTAssertNil(turn.latest)
    XCTAssertEqual(turn.replied(version: 3, now: at(140)), .done, "nothing moved since: no second picture")
    XCTAssertFalse(turn.looking)
  }

  func testHisAnswerWithNothingNewSendsNothing() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.replied(version: 1, now: at(60)), .done)
    XCTAssertEqual(turn.state, .idle)
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(61)), .send(words: nil), "the next pause goes at once")
  }

  func testAnAnswerWithNoTurnOutIsNothing() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.replied(version: 1, now: at(0)), .done)
    XCTAssertFalse(turn.looking)
  }

  func testTheTurnTimesOut() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertNil(turn.tick(version: 1, now: at(179)), "still in time")
    XCTAssertEqual(turn.tick(version: 1, now: at(180)), .done)
    XCTAssertFalse(turn.looking)
    XCTAssertNil(turn.tick(version: 1, now: at(400)), "no turn out")
  }

  func testAShorterTimeoutEndsTheTurnSooner() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertNil(turn.tick(version: 1, now: at(4), timeout: .seconds(5)), "still in time")
    XCTAssertEqual(turn.tick(version: 1, now: at(5), timeout: .seconds(5)), .done)
    XCTAssertFalse(turn.looking)
  }

  func testATimeoutWithTheBoardMovedOnSendsTheLatest() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: nil, now: at(30))
    XCTAssertEqual(turn.tick(version: 3, now: at(181)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(181), sent: 3), "the picture is of the board as it is now")
  }

  func testATapSupersedesWhatWasWaiting() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: "circle the middle", now: at(5))
    XCTAssertEqual(
      turn.tapped(version: 3, now: at(10)), .send(words: "circle the middle"), "the waiting words go with it")
    XCTAssertEqual(turn.state, .awaiting(since: at(10), sent: 3))
    XCTAssertNil(turn.latest)
    XCTAssertEqual(turn.replied(version: 3, now: at(70)), .done, "what waited went with the tap")
  }

  func testATapWhileIdleSendsAtOnce() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.tapped(version: 1, now: at(0)), .send(words: nil))
    XCTAssertTrue(turn.looking)
  }

  // Story 765: a repeat tap sends nothing.

  func testARepeatTapWithNothingNewSendsNothing() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.tapped(version: 1, now: at(0)), .send(words: nil))
    XCTAssertEqual(turn.tapped(version: 1, now: at(12)), .alreadyHas)
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 1), "the clock keeps timing the first picture")
    XCTAssertEqual(turn.alreadyHasAt, at(12))
    XCTAssertEqual(turn.tapped(version: 1, now: at(13)), .alreadyHas, "and again")
  }

  // Stories 970–972 (beads context-grabber-ts8a, kxzk): the blocked chip's Retry hands Larry the board even when he
  // has this picture; only the Send button is refused then.
  func testABlockedEditsRetryHandsOverTheBoardLarryAlreadyHas() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.tapped(version: 1, now: at(0)), .send(words: nil))
    XCTAssertEqual(turn.tapped(version: 1, now: at(5)), .alreadyHas, "Send still answers he has it")
    XCTAssertEqual(turn.tapped(version: 1, handOver: true, now: at(8)), .send(words: nil), "Retry goes")
    XCTAssertEqual(turn.state, .awaiting(since: at(8), sent: 1), "and his clock restarts")
    XCTAssertNil(turn.alreadyHasAt, "a picture that went clears the note")
  }

  func testAPauseThatSentCountsToo() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 4, words: nil, now: at(0))
    XCTAssertEqual(turn.tapped(version: 4, now: at(3)), .alreadyHas)
  }

  func testARepeatTapAfterAStrokeSends() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    _ = turn.tapped(version: 1, now: at(5))
    XCTAssertEqual(turn.tapped(version: 2, now: at(12)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(12), sent: 2), "the clock restarts")
    XCTAssertNil(turn.alreadyHasAt, "a picture that went clears the note")
  }

  // Spec, *A repeat tap sends nothing*: another part of the board on screen is something new (story 433's pages).
  func testARepeatTapWithAnotherPartOfTheBoardOnScreenSends() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    XCTAssertEqual(turn.tapped(version: 1, moved: true, now: at(12)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(12), sent: 1), "the clock restarts")
    XCTAssertEqual(turn.tapped(version: 1, moved: false, now: at(14)), .alreadyHas, "he has that part now")
  }

  func testARepeatTapWithWordsWaitingSends() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    XCTAssertEqual(turn.paused(version: 1, words: "label it", now: at(4)), .held)
    XCTAssertEqual(turn.tapped(version: 1, now: at(12)), .send(words: "label it"))
    XCTAssertEqual(turn.state, .awaiting(since: at(12), sent: 1))
  }

  // Bead context-grabber-x3tm (Igor, 2026-11-22): once he has this picture, Send is dimmed until the next stroke, his
  // answer or not.
  func testAfterHisAnswerHeStillHasTheBoardUntilTheNextStroke() {
    var turn = WhiteboardLarryTurn()
    XCTAssertFalse(turn.hasThis(version: 1, moved: false), "nothing has gone yet")
    _ = turn.tapped(version: 1, now: at(0))
    XCTAssertTrue(turn.hasThis(version: 1, moved: false), "while he looks")
    XCTAssertEqual(turn.replied(version: 1, now: at(40)), .done)
    XCTAssertTrue(turn.hasThis(version: 1, moved: false), "and after he answers")
    XCTAssertEqual(turn.tapped(version: 1, now: at(41)), .alreadyHas, "a tap that arrives anyway sends nothing")
    XCTAssertFalse(turn.hasThis(version: 2, moved: false), "the next stroke lights it")
    XCTAssertFalse(turn.hasThis(version: 1, moved: true), "so do other pages on screen")
    XCTAssertEqual(turn.tapped(version: 2, now: at(42)), .send(words: nil))
  }

  func testAPictureThatDidntReachHimLightsSend() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    turn.failed(turn.state, words: nil)
    XCTAssertFalse(turn.hasThis(version: 1, moved: false))
  }

  // Story 805: Interrupt makes the next tap a fresh ask.
  func testInterruptLightsSend() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    XCTAssertTrue(turn.interrupted())
    XCTAssertFalse(turn.hasThis(version: 1, moved: false))
    XCTAssertEqual(turn.tapped(version: 1, now: at(2)), .send(words: nil))
  }

  func testATimeoutLeavesHimWithTheBoard() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    XCTAssertEqual(turn.tick(version: 1, now: at(181)), .done)
    XCTAssertTrue(turn.hasThis(version: 1, moved: false))
  }

  func testAReopenedWaitingSendIsOfItsOwnVersion() {
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(sent: 3, version: 5, now: at(0))
    XCTAssertTrue(turn.outboxSent(now: at(1)))
    XCTAssertTrue(turn.hasThis(version: 3, moved: false))
    XCTAssertFalse(turn.hasThis(version: 5, moved: false), "ink drawn after the Send is new")
  }

  func testAFailedPictureLetsTheSameBoardGoAgain() {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: 1, now: at(0))
    turn.failed(turn.state, words: nil)
    XCTAssertEqual(turn.tapped(version: 1, now: at(2)), .send(words: nil))
  }

  func testWordsWaitForTheNextPicture() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.paused(version: 1, words: "draw a box", now: at(0)), .send(words: "draw a box"))
    XCTAssertEqual(turn.paused(version: 1, words: "and an arrow", now: at(3)), .held)
    XCTAssertEqual(turn.paused(version: 1, words: "to the left", now: at(6)), .held)
    XCTAssertEqual(turn.queued, "and an arrow to the left")
    XCTAssertEqual(
      turn.replied(version: 1, now: at(60)), .send(words: "and an arrow to the left"),
      "words alone are reason enough for a picture")
    XCTAssertNil(turn.queued)
  }

  func testAFailedPictureFreesTheTurnAndKeepsItsWords() {
    var turn = WhiteboardLarryTurn()
    guard case .send(let words) = turn.paused(version: 1, words: "draw a box", now: at(0)) else {
      return XCTFail("the first pause sends")
    }
    let sent = turn.state
    _ = turn.paused(version: 1, words: "now", now: at(1))
    turn.failed(sent, words: words)
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(5)), .send(words: "draw a box now"))
  }

  func testAnOlderPictureFailingLeavesANewerTurnOut() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    let first = turn.state
    XCTAssertEqual(turn.tapped(version: 2, now: at(4)), .send(words: nil))
    turn.failed(first, words: "draw a box")
    XCTAssertTrue(turn.looking, "the tapped picture's answer is still out")
    XCTAssertEqual(turn.state, .awaiting(since: at(4), sent: 2))
    XCTAssertEqual(turn.paused(version: 3, words: nil, now: at(6)), .held, "one turn out at a time")
    XCTAssertEqual(turn.replied(version: 3, now: at(60)), .send(words: "draw a box"))
  }

  func testGhostsOffForgetsWhatWasWaiting() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: "more", now: at(5))
    turn.dropped()
    XCTAssertTrue(turn.looking, "the turn already out stays out")
    XCTAssertEqual(turn.replied(version: 2, now: at(60)), .done)
  }

  func testOnlyNewRowsAreAnAnswer() {
    var marks = WhiteboardMarks()
    let old = WhiteboardMarks.Row(id: "a", text: "earlier")
    XCTAssertFalse(marks.take([old], settled: []).replied, "the first look's rows were there before")
    XCTAssertFalse(marks.take([old], settled: []).replied)
    XCTAssertTrue(marks.take([old, .init(id: "b", text: "ok")], settled: []).replied)
  }

  // MARK: #913: he closes the turn with nothing to say

  func testDoneWithNothingNewEndsTheTurnAndSendsNothing() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.closed(version: 1, now: at(15)), .done)
    XCTAssertFalse(turn.looking)
    XCTAssertTrue(turn.nothingToAdd)
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(20)), .send(words: nil), "the next pause goes at once")
    XCTAssertFalse(turn.nothingToAdd, "a new turn takes the note back")
  }

  func testDoneWithTheBoardMovedOnSendsExactlyOnePicture() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: "and label it", now: at(5))
    _ = turn.paused(version: 3, words: nil, now: at(8))
    XCTAssertEqual(turn.closed(version: 3, now: at(15)), .send(words: "and label it"))
    XCTAssertEqual(turn.state, .awaiting(since: at(15), sent: 3))
    XCTAssertFalse(turn.nothingToAdd, "a fresh picture went: his clock, not the note")
    XCTAssertEqual(turn.closed(version: 3, now: at(16)), .done, "the same mark read again sends nothing more")
  }

  func testALateReplyAfterDoneDoesNotSendAgain() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.closed(version: 1, now: at(15)), .done)
    XCTAssertEqual(turn.replied(version: 1, now: at(20)), .done)
    XCTAssertFalse(turn.looking)
    XCTAssertFalse(turn.nothingToAdd, "he did say something after all")
  }

  func testALateReplyAfterDoneThatSentOnceDoesNotSendAgain() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: nil, now: at(5))
    XCTAssertEqual(turn.closed(version: 2, now: at(15)), .send(words: nil))
    XCTAssertEqual(turn.replied(version: 2, now: at(20)), .done, "the board hasn't moved since: no second picture")
  }

  func testDoneWithNoTurnOutIsNothing() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.closed(version: 1, now: at(0)), .done)
    XCTAssertFalse(turn.nothingToAdd)
  }
}
