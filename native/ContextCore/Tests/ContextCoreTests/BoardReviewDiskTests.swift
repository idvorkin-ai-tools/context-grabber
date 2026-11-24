import Foundation
import XCTest

@testable import ContextCore

/// Story 1312 (bead context-grabber-04ks): a session is reviewed once.
final class BoardReviewDiskTests: XCTestCase {
  private var root: URL!

  override func setUp() {
    super.setUp()
    root = FileManager.default.temporaryDirectory.appendingPathComponent("board-reviews-\(UUID().uuidString)")
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: root)
    super.tearDown()
  }

  /// A session of one stroke of Igor's, begun at `began`.
  private func session(began: Double) -> BoardSessionRecord {
    var recorder = BoardReviewRecorder(board: "b")
    recorder.begin(ink: [:], folds: [])
    let a = BoardSessionRecord.Box(10, 10, 40, 20)
    recorder.take(
      type: "whiteboard", t: began, fields: ["action": "paper_open", "board": "b"], ink: [:], folds: [])
    recorder.take(
      type: "whiteboard", t: began + 100, fields: ["action": "paper_ink", "board": "b", "in_touch": true],
      ink: ["a": .init(owner: "igor", box: a)])
    return recorder.record!
  }

  private var disk: BoardReviewDisk { BoardReviewDisk(board: "b", root: root) }

  /// Story 1312: a write of the session that was already on its way when the board closed lands after the close's
  /// review, and leaves nothing for the next open to review again.
  func testAWriteLandingAfterTheReviewLeavesNothingPending() {
    let record = session(began: 1000)
    disk.keepPending(record)
    disk.clearPending(session: record.header.session)
    disk.keep(record, BoardReview.run(record))
    disk.keepPending(record)  // the write that was in flight
    XCTAssertNil(disk.pending(), "a session already reviewed is never pending again")
  }

  /// Story 1312: a pending session that was reviewed after all (the app closed between the review and the clear) is
  /// dropped on the next open, not reviewed a second time.
  func testAPendingSessionAlreadyReviewedIsNotReviewedAgain() {
    let record = session(began: 1000)
    disk.keep(record, BoardReview.run(record))
    try? FileManager.default.createDirectory(at: disk.folder, withIntermediateDirectories: true)
    try? record.jsonl().write(to: disk.pendingURL)
    XCTAssertNil(disk.takePending(), "already reviewed: nothing to review")
    XCTAssertNil(disk.pending(), "and it is cleared")
  }

  /// Story 1312: the next open still reviews a session the app's closing cut short.
  func testACutShortSessionIsReviewedOnTheNextOpen() {
    let record = session(began: 1000)
    disk.keepPending(record)
    XCTAssertEqual(disk.takePending()?.header.session, record.header.session)
    XCTAssertNil(disk.pending(), "taken once")
  }

  /// Story 1312: closing one session's review never clears the next session's pending record.
  func testClearingOneSessionLeavesTheNextSessionPending() {
    let first = session(began: 1000)
    let next = session(began: 9000)
    disk.keepPending(next)
    disk.clearPending(session: first.header.session)
    XCTAssertEqual(disk.pending()?.header.session, next.header.session)
  }
}
