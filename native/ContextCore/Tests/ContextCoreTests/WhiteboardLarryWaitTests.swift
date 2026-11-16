import Foundation
import XCTest

@testable import ContextCore

/// Stories 773, 775–777: where the picture is, from the Cockpit's mark on its message, and what the board offers
/// twenty seconds into Larry's turn.
final class WhiteboardLarryWaitTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  private func out(at seconds: Int = 0, version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: version, now: at(seconds))
    return turn
  }

  func testNoTurnOutOffersNothing() {
    for mark in [WhiteboardLarryWait.Mark.none, .unknown, .received, .seen, .done] {
      XCTAssertEqual(WhiteboardLarryWait.of(WhiteboardLarryTurn(), mark: mark, now: at(60)), .none)
    }
  }

  func testUnderTwentySecondsOffersNothingWhateverTheMark() {
    for mark in [WhiteboardLarryWait.Mark.none, .unknown, .received, .seen] {
      XCTAssertEqual(WhiteboardLarryWait.of(out(), mark: mark, now: at(19)), .waiting)
    }
  }

  func testNoMarkAtTwentySecondsIsStuckWithRetryAndDismiss() {
    XCTAssertEqual(WhiteboardLarryWait.of(out(), mark: .none, now: at(20)), .stuck)
  }

  func testReceivedSeenOrUnknownAtTwentySecondsIsWorkingWithOnlyInterrupt() {
    for mark in [WhiteboardLarryWait.Mark.received, .seen, .unknown] {
      XCTAssertEqual(WhiteboardLarryWait.of(out(), mark: mark, now: at(25)), .working, "\(mark)")
    }
  }

  func testDoneOffersNothingEvenWithTheTurnStillOut() {
    XCTAssertEqual(WhiteboardLarryWait.of(out(), mark: .done, now: at(90)), .none)
  }

  func testTheTwentySecondsCountFromTheNewestPicture() {
    var turn = out(at: 0, version: 1)
    _ = turn.tapped(version: 2, now: at(15))
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .none, now: at(25)), .waiting, "a newer picture restarts it")
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .none, now: at(35)), .stuck)
  }

  func testRetryStartsTheTwentySecondsAgainOnTheSamePicture() {
    var turn = out()
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .none, now: at(21)), .stuck)
    XCTAssertTrue(turn.resent(now: at(21)))
    XCTAssertEqual(turn.state, .awaiting(since: at(21), sent: 1), "same version, a new clock")
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .none, now: at(30)), .waiting)
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .received, now: at(41)), .working, "it landed this time")
  }

  func testDismissFreesTheTurnAndKeepsItsWords() {
    var turn = WhiteboardLarryTurn()
    guard case .send(let words) = turn.paused(version: 1, words: "a circle", now: at(0)) else {
      return XCTFail("expected a send")
    }
    XCTAssertEqual(words, "a circle")
    turn.failed(turn.state, words: words)
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .none, now: at(30)), .none)
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.queued, "a circle", "the words wait for the next picture")
  }

  func testInterruptFreesTheTurnAndALateAnswerFindsNone() {
    var turn = out()
    _ = turn.paused(version: 3, words: "and a square", now: at(10))
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .seen, now: at(30)), .working)
    XCTAssertTrue(turn.interrupted())
    XCTAssertEqual(WhiteboardLarryWait.of(turn, mark: .seen, now: at(31)), .none)
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

  // MARK: Where the picture is: one reading for the state and the controls

  private let wall = Date(timeIntervalSince1970: 1_800_000_000)

  private func igor(_ id: String, _ secondsAfterPicture: Double, _ receipt: ChatMessage.Receipt) -> ChatMessage {
    let format = ISO8601DateFormatter()
    format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let ts = format.string(from: wall + secondsAfterPicture)
    return ChatMessage(id: id, ts: ts, who: "igor", text: "", attachments: ["a.jpg"], receipt: receipt)
  }

  /// The picture went at `wall`; the board reads the thread ten seconds later.
  private func mark(
    _ thread: [ChatMessage], picture: String? = nil, delivered: Bool = false,
    earlier: ChatMessage.Receipt = .sent, turn: WhiteboardLarryTurn? = nil
  ) -> WhiteboardLarryWait.Mark {
    WhiteboardLarryWait.mark(
      turn ?? out(), thread: thread, now: at(10), wallNow: wall + 10, picture: picture, delivered: delivered,
      earlier: earlier)
  }

  func testThePicturesOwnMarkSaysWhereItIs() {
    let older = igor("old", -60, .done)
    XCTAssertEqual(mark([older, igor("pic", 1, .received)], picture: "pic"), .received)
    XCTAssertEqual(mark([older, igor("pic", 1, .seen)], picture: "pic"), .seen)
    XCTAssertEqual(mark([older, igor("pic", 1, .done)], picture: "pic"), .done)
    XCTAssertEqual(
      mark([igor("pic", 1, .seen)], picture: "pic", earlier: .done), .done, "a stale look never takes it back")
  }

  func testNoMarkIsStuckOnlyOnACockpitThatMarks() {
    let marked = igor("old", -60, .done)
    XCTAssertEqual(mark([marked, igor("pic", 1, .sent)], picture: "pic"), .none, "its message, unmarked")
    XCTAssertEqual(mark([marked], picture: "pic"), .none, "no such message on a thread that marks")
    XCTAssertEqual(
      WhiteboardLarryWait.of(out(), mark: mark([marked], picture: "pic"), now: at(20)), .stuck,
      "Retry and Dismiss at twenty seconds")
  }

  func testAnOlderCockpitIsNeverStuck() {
    let unmarked = [igor("old", -60, .sent), igor("pic", 1, .sent)]
    XCTAssertEqual(mark(unmarked, picture: "pic"), .unknown, "no message of Igor's carries a mark")
    XCTAssertEqual(mark([], picture: "pic"), .unknown, "the thread not read yet: a board's first picture")
    XCTAssertEqual(mark(unmarked, picture: "pic", delivered: true), .unknown, "a landed picture never reads Sent there")
    XCTAssertEqual(
      WhiteboardLarryWait.of(out(), mark: mark(unmarked, picture: "pic"), now: at(25)), .working,
      "Interrupt from twenty seconds, never Retry")
  }

  func testAPictureTheCockpitAnsweredForIsNeverStuck() {
    XCTAssertEqual(
      mark([igor("old", -60, .done)], picture: "pic", delivered: true), .received,
      "its sending answered, the thread not read since")
  }

  func testASendToLarryIsReadByTheNewestMessageSinceThePicture() {
    XCTAssertEqual(mark([igor("1", 1, .received)]), .received)
    XCTAssertEqual(mark([igor("1", 1, .seen)]), .seen)
    XCTAssertEqual(mark([igor("0", -60, .done)]), .unknown, "an earlier picture's mark says nothing of this one")
    XCTAssertEqual(mark([igor("0", -60, .done), igor("1", 1, .sent)]), .unknown, "no picture id: never stuck")
    XCTAssertEqual(mark([igor("1", -0.5, .seen)]), .seen, "a whole-second timestamp a moment early is still it")
    let larry = ChatMessage(id: "l", ts: igor("x", 5, .sent).ts, who: "larry", text: "hm")
    XCTAssertEqual(mark([igor("1", 1, .received), larry]), .received, "Larry's own rows carry no mark")
  }

  func testNoTurnOutIsUnknown() {
    XCTAssertEqual(mark([igor("pic", 1, .seen)], picture: "pic", turn: WhiteboardLarryTurn()), .unknown)
  }

  // MARK: After Interrupt or Dismiss, and the hand-offs Retry and Dismiss replace

  func testAfterInterruptOrDismissTheNextTapSends() {
    var interrupted = out()
    XCTAssertTrue(interrupted.interrupted())
    XCTAssertEqual(interrupted.tapped(version: 1, now: at(30)), .send(words: nil), "never Larry already has this")
    var dismissed = out()
    dismissed.failed(dismissed.state, words: nil)
    XCTAssertEqual(dismissed.tapped(version: 1, now: at(30)), .send(words: nil))
  }

  func testAFailureOfThePictureBeforeRetryNeverFreesTheRetriedTurn() {
    var turn = out()
    let first = turn.state
    XCTAssertTrue(turn.resent(now: at(21)))
    turn.failed(first, words: "a circle")
    XCTAssertTrue(turn.looking, "the retried turn stays out")
    XCTAssertEqual(turn.queued, "a circle")
  }

  func testAHandOffReplacedByRetryOrDismissSpeaksNoMore() {
    var handOffs = WhiteboardLarryHandOffs()
    let first = handOffs.begin()
    handOffs.replace(first)
    let retried = handOffs.begin()
    XCTAssertFalse(handOffs.speaks(first), "Retry took it over: its words go with the retry")
    XCTAssertTrue(handOffs.speaks(retried))
    XCTAssertTrue(handOffs.isLatest(retried))
    XCTAssertFalse(handOffs.isLatest(first))
  }

  func testAHandOffANewerPictureReplacedStillSpeaks() {
    var handOffs = WhiteboardLarryHandOffs()
    let first = handOffs.begin()
    let newer = handOffs.begin()
    XCTAssertTrue(handOffs.speaks(first), "its failure still keeps its words and says so")
    XCTAssertFalse(handOffs.isLatest(first), "but it no longer says whether a picture is on its way")
    XCTAssertTrue(handOffs.isLatest(newer))
  }

  // MARK: #913: done with no reply

  func testDoneWithNoReplyAfterItClosesTheTurn() {
    let thread = [
      ChatMessage(id: "larry-0", ts: "", who: "larry", text: "earlier"),
      ChatMessage(id: "pic", ts: "", who: "igor", text: "", receipt: .done),
    ]
    XCTAssertTrue(WhiteboardLarryWait.doneWithoutReply("pic", in: thread))
  }

  func testDoneWithAReplyAfterItIsTheReplysToEnd() {
    let thread = [
      ChatMessage(id: "pic", ts: "", who: "igor", text: "", receipt: .done),
      ChatMessage(id: "larry-1", ts: "", who: "larry", text: "nice"),
    ]
    XCTAssertFalse(WhiteboardLarryWait.doneWithoutReply("pic", in: thread))
  }

  func testReceivedOrSeenDoesNotCloseTheTurn() {
    for receipt in [ChatMessage.Receipt.sent, .received, .seen] {
      let thread = [ChatMessage(id: "pic", ts: "", who: "igor", text: "", receipt: receipt)]
      XCTAssertFalse(WhiteboardLarryWait.doneWithoutReply("pic", in: thread), "\(receipt)")
    }
  }

  func testAPictureNotOnTheThreadDoesNotCloseTheTurn() {
    let thread = [ChatMessage(id: "other", ts: "", who: "igor", text: "", receipt: .done)]
    XCTAssertFalse(WhiteboardLarryWait.doneWithoutReply("pic", in: thread))
  }
}
