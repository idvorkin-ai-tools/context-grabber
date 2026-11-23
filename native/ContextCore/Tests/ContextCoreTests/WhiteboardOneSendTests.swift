import Foundation
import XCTest

@testable import ContextCore

/// Story 1176 (bead context-grabber-rtl): one Send button. A Send waiting in the outbox holds the turn, says
/// *Waiting to send*, never times out or reads stuck, and lets nothing else go; when the outbox sends it his clock
/// starts; refused or deleted, the turn is free and its words wait.
final class WhiteboardOneSendTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  /// A tap at `seconds` whose picture went into the outbox.
  private func waiting(at seconds: Int = 0, version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.tapped(version: version, now: at(seconds)), .send(words: nil))
    turn.waitsInOutbox()
    return turn
  }

  func testWhileItWaitsTheBoardSaysSoAndNotHisClock() {
    let turn = waiting()
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(12), cockpitAnswering: true), "Waiting to send · 0:12")
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(12), cockpitAnswering: false, mark: .received),
      "Waiting to send · 0:12", "nothing about him or the Cockpit: it hasn't left the iPad")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(12), cockpitAnswering: true), "Waiting to send for 12 seconds")
  }

  func testWhileItWaitsNothingElseGoes() {
    var turn = waiting()
    XCTAssertEqual(turn.paused(version: 2, words: "and label it", now: at(5)), .held, "a pause sends nothing")
    XCTAssertEqual(turn.replied(version: 2, now: at(6)), .held, "an answer to an earlier picture sends nothing")
    XCTAssertEqual(turn.closed(version: 2, now: at(7)), .held)
    XCTAssertNil(turn.tick(version: 2, now: at(600)), "the three minutes don't run while it waits")
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertFalse(turn.interrupted(), "nothing to interrupt: he hasn't got it")
    XCTAssertEqual(
      WhiteboardLarryWait.of(turn, mark: .none, now: at(60)), .none, "never stuck: the outbox keeps trying")
  }

  func testWhenItGoesHisClockStartsAndTheTimeoutCountsFromThere() {
    var turn = waiting()
    XCTAssertTrue(turn.outboxSent(now: at(300)))
    XCTAssertFalse(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(300), cockpitAnswering: true), "Larry · 0:00")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(342), cockpitAnswering: true), "Larry · 0:42")
    XCTAssertNil(turn.tick(version: 1, now: at(400)), "three minutes from when it went, not from the tap")
    XCTAssertEqual(turn.tick(version: 1, now: at(480)), .done)
    XCTAssertFalse(turn.outboxSent(now: at(500)), "once")
  }

  func testAfterItGoesARepeatTapIsAnsweredAsAlways() {
    var turn = waiting()
    _ = turn.outboxSent(now: at(10))
    XCTAssertEqual(turn.tapped(version: 1, now: at(11)), .alreadyHas, "story 765")
    XCTAssertEqual(turn.tapped(version: 2, now: at(12)), .send(words: nil), "a stroke since sends")
  }

  func testRefusedOrDeletedFreesTheTurnAndItsWordsWait() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 1, words: "the arrow", now: at(1))
    _ = turn.interrupted()
    XCTAssertEqual(turn.tapped(version: 2, now: at(2)), .send(words: "the arrow"))
    turn.waitsInOutbox()
    turn.failed(turn.state, words: "the arrow")
    XCTAssertFalse(turn.looking)
    XCTAssertFalse(turn.waitingToSend)
    XCTAssertEqual(turn.tapped(version: 2, now: at(3)), .send(words: "the arrow"), "the words go with the next")
  }

  func testABoardOpenedWhileItsSendWaitsIsWaitingAgain() {
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(version: 4, now: at(0))
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(3), cockpitAnswering: true), "Waiting to send · 0:03")
    XCTAssertTrue(turn.outboxSent(now: at(5)))
    XCTAssertEqual(turn.state, .awaiting(since: at(5), sent: 4))
  }

  // MARK: Opened again while it waits (story 1192, bead context-grabber-kocz)

  /// A Send taken at the board's version `rev` of `rect` (`folds` open), as the outbox gives it back (its JSON;
  /// `WhiteboardMarksTests` takes one through the outbox's store).
  private func queued(rev: Int, rect: CGRect, folds: BoardFoldMap? = nil) throws -> WhiteboardPicture {
    var picture = WhiteboardPicture(
      board: "b1", title: "Plan", rect: folds.map { $0.toPicture(rect) } ?? rect, scale: 2,
      report: BoardTurnReport(rev: rev))
    picture.folds = folds
    return try JSONDecoder().decode(WhiteboardPicture.self, from: JSONEncoder().encode(picture))
  }

  private let shown = CGRect(x: 12.3, y: 401.7, width: 820.1, height: 1100.9)

  func testAReopenedSendThatWentIsNotSentAgainOnARepeatTap() throws {
    let picture = try queued(rev: 4, rect: shown)
    XCTAssertEqual(picture.report?.rev, 4, "the outbox keeps the picture's revision")
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(sent: picture.report?.rev, version: 4, now: at(0))
    XCTAssertTrue(turn.outboxSent(now: at(5)))
    let frame = WhiteboardLarryFrame.picture(picture)
    XCTAssertFalse(frame.moved(to: shown))
    XCTAssertEqual(
      turn.tapped(version: 4, moved: frame.moved(to: shown), now: at(6)), .alreadyHas,
      "the same pages, nothing new: no second copy")
    XCTAssertTrue(frame.moved(to: shown.offsetBy(dx: 0, dy: 300)), "other pages on screen")
    XCTAssertEqual(turn.tapped(version: 4, moved: true, now: at(7)), .send(words: nil))
  }

  func testInkDrawnAfterTheSendBeforeTheBoardClosedIsStillNew() throws {
    let picture = try queued(rev: 4, rect: shown)
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(sent: picture.report?.rev, version: 6, now: at(0))
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 4), "the picture's revision, not the board's now")
    _ = turn.outboxSent(now: at(5))
    XCTAssertEqual(
      turn.tapped(version: 6, moved: WhiteboardLarryFrame.picture(picture).moved(to: shown), now: at(6)),
      .send(words: nil), "the two strokes drawn after it go")
  }

  func testAPictureThatDoesntSayItsRevisionIsTakenAsTheBoardNow() {
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(sent: nil, version: 6, now: at(0))
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 6))
    var behind = WhiteboardLarryTurn()
    behind.reopenedWaiting(sent: 9, version: 6, now: at(0))
    XCTAssertEqual(behind.state, .awaiting(since: at(0), sent: 6), "never ahead of the board")
  }

  func testAWaitingPictureWithFoldsOpenShowsThePagesItWasTakenOf() throws {
    let folds = BoardFoldMap(steps: [
      BoardFoldMap.Step(header: "h1", top: 500.1, slide: 0.2), BoardFoldMap.Step(header: "h2", top: 900.3, slide: 77.7),
    ])
    let picture = try queued(rev: 4, rect: shown, folds: folds)
    XCTAssertEqual(picture.folds, folds, "the outbox keeps the folds")
    XCTAssertNotEqual(picture.frame.h, Double(shown.height), "the frame is the taller picture")
    XCTAssertTrue(picture.shows(shown))
    XCTAssertFalse(picture.shows(shown.offsetBy(dx: 0, dy: 1)))
    XCTAssertFalse(WhiteboardLarryFrame.picture(picture).moved(to: shown))
    XCTAssertTrue(WhiteboardLarryFrame.rect(shown).moved(to: shown.insetBy(dx: 1, dy: 1)))
  }

  /// Bead context-grabber-8lsj: words a pause hears while the Send waits go with the picture after his answer, or with
  /// the next Send if it can't go.
  func testWordsSpokenWhileItWaitsGoWithTheNextPicture() {
    var turn = waiting()
    XCTAssertEqual(turn.paused(version: 1, words: "label the arrow", now: at(5)), .held)
    XCTAssertTrue(turn.wordsWaiting)
    XCTAssertTrue(turn.outboxSent(now: at(10)))
    XCTAssertTrue(turn.wordsWaiting, "still kept once it has gone")
    XCTAssertEqual(turn.replied(version: 1, now: at(40)), .send(words: "label the arrow"))

    var refused = waiting()
    _ = refused.paused(version: 2, words: "and the box", now: at(5))
    refused.failed(refused.state, words: nil)
    XCTAssertEqual(refused.tapped(version: 2, now: at(6)), .send(words: "and the box"), "kept when it can't go")
  }

  func testWaitingIsOnlyForATurnOut() {
    var turn = WhiteboardLarryTurn()
    turn.waitsInOutbox()
    XCTAssertFalse(turn.waitingToSend, "no turn out: nothing waits")
  }

  // MARK: The strokes file

  func testTheStrokesFileCarriesTheFoldsBesideTheStrokes() throws {
    let strokes: [[String: Any]] = [["id": "s1", "points": [[1, 2]]]]
    let folds: [[String: Any]] = [["header": "h1", "strokes": ["s2"]]]
    let plain = try XCTUnwrap(WhiteboardStrokes.file(try WhiteboardStrokes.file(strokes: strokes, folds: [])))
    XCTAssertEqual(plain.strokes.first?["id"] as? String, "s1")
    XCTAssertTrue(plain.folds.isEmpty)
    let raw = try WhiteboardStrokes.file(strokes: strokes, folds: folds)
    XCTAssertTrue(try JSONSerialization.jsonObject(with: raw) is [String: Any], "with folds, the strokes and folds")
    let both = try XCTUnwrap(WhiteboardStrokes.file(raw))
    XCTAssertEqual(both.strokes.first?["id"] as? String, "s1")
    XCTAssertEqual(both.folds.first?["header"] as? String, "h1")
    XCTAssertNil(WhiteboardStrokes.file(Data("nope".utf8)))
  }
}
