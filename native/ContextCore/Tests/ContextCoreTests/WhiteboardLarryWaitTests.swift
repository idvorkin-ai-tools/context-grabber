import XCTest

@testable import ContextCore

/// Stories 773–775: what the board offers twenty seconds into Larry's turn, from the Cockpit's mark on the picture.
final class WhiteboardLarryWaitTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  private func out(at seconds: Int = 0, version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: version, now: at(seconds))
    return turn
  }

  func testNoTurnOutOffersNothing() {
    for receipt in [ChatMessage.Receipt.sent, .received, .seen, .done] {
      XCTAssertEqual(WhiteboardLarryWait.of(WhiteboardLarryTurn(), receipt: receipt, now: at(60)), .none)
    }
  }

  func testUnderTwentySecondsOffersNothingWhateverTheMark() {
    for receipt in [ChatMessage.Receipt.sent, .received, .seen] {
      XCTAssertEqual(WhiteboardLarryWait.of(out(), receipt: receipt, now: at(19)), .waiting)
      XCTAssertEqual(WhiteboardLarryWait.of(out(), receipt: receipt, now: at(19)).controls, [])
    }
  }

  func testNoMarkAtTwentySecondsIsStuckWithRetryAndDismiss() {
    let wait = WhiteboardLarryWait.of(out(), receipt: .sent, now: at(20))
    XCTAssertEqual(wait, .stuck)
    XCTAssertEqual(wait.controls, [.retry, .dismiss])
  }

  func testReceivedOrSeenAtTwentySecondsIsWorkingWithOnlyInterrupt() {
    for receipt in [ChatMessage.Receipt.received, .seen] {
      let wait = WhiteboardLarryWait.of(out(), receipt: receipt, now: at(25))
      XCTAssertEqual(wait, .working, "\(receipt)")
      XCTAssertEqual(wait.controls, [.interrupt])
    }
  }

  func testDoneOffersNothingEvenWithTheTurnStillOut() {
    XCTAssertEqual(WhiteboardLarryWait.of(out(), receipt: .done, now: at(90)), .none)
  }

  func testTheThresholdCanBeShortened() {
    XCTAssertEqual(WhiteboardLarryWait.of(out(), receipt: .sent, now: at(3), after: .seconds(3)), .stuck)
  }

  func testTheTwentySecondsCountFromTheNewestPicture() {
    var turn = out(at: 0, version: 1)
    _ = turn.tapped(version: 2, now: at(15))
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .sent, now: at(25)), .waiting, "a newer picture restarts it")
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .sent, now: at(35)), .stuck)
  }

  func testRetryStartsTheTwentySecondsAgainOnTheSamePicture() {
    var turn = out()
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .sent, now: at(21)), .stuck)
    XCTAssertTrue(turn.resent(now: at(21)))
    XCTAssertEqual(turn.state, .awaiting(since: at(21), sent: 1), "same version, a new clock")
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .sent, now: at(30)), .waiting)
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .received, now: at(41)), .working, "it landed this time")
  }

  func testDismissFreesTheTurnAndKeepsItsWords() {
    var turn = WhiteboardLarryTurn()
    guard case .send(let words) = turn.paused(version: 1, words: "a circle", now: at(0)) else {
      return XCTFail("expected a send")
    }
    XCTAssertEqual(words, "a circle")
    turn.failed(turn.state, words: words)
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .sent, now: at(30)), .none)
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.queued, "a circle", "the words wait for the next picture")
  }

  func testInterruptFreesTheTurnAndALateAnswerFindsNone() {
    var turn = out()
    _ = turn.paused(version: 3, words: "and a square", now: at(10))
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .seen, now: at(30)), .working)
    XCTAssertTrue(turn.interrupted())
    XCTAssertEqual(WhiteboardLarryWait.of(turn, receipt: .seen, now: at(31)), .none)
    XCTAssertNil(turn.latest, "the next picture takes the board as it is then")
    XCTAssertEqual(turn.queued, "and a square", "waiting words go with the next picture")
    XCTAssertEqual(turn.replied(version: 3, now: at(70)), .done, "his late answer sends nothing")
    XCTAssertEqual(
      turn.paused(version: 4, words: nil, now: at(71)), .send(words: "and a square"), "the next pause is a fresh ask")
  }

  func testRetryAndInterruptNeedATurnOut() {
    var turn = WhiteboardLarryTurn()
    XCTAssertFalse(turn.resent(now: at(1)))
    XCTAssertFalse(turn.interrupted())
    XCTAssertEqual(turn.state, .idle)
  }

  func testTheMarkOnlyMovesForward() {
    XCTAssertEqual(ChatMessage.Receipt.sent.atLeast(.received), .received)
    XCTAssertEqual(ChatMessage.Receipt.seen.atLeast(.received), .seen, "a stale look never takes it back")
    XCTAssertEqual(ChatMessage.Receipt.done.atLeast(.sent), .done)
    XCTAssertEqual(ChatMessage.Receipt.received.atLeast(.received), .received)
  }

  func testTheMarkIsFoundByTheMessagesId() {
    let messages = [
      ChatMessage(id: "pic-a", ts: "", who: "igor", text: "", receipt: .done),
      ChatMessage(id: "larry-1", ts: "", who: "larry", text: "nice"),
      ChatMessage(id: "pic-b", ts: "", who: "igor", text: "", receipt: .seen),
    ]
    XCTAssertEqual(WhiteboardLarryWait.receipt(of: "pic-b", in: messages), .seen)
    XCTAssertEqual(WhiteboardLarryWait.receipt(of: "pic-a", in: messages), .done)
    XCTAssertNil(WhiteboardLarryWait.receipt(of: "pic-c", in: messages), "not on the thread yet")
  }
}
