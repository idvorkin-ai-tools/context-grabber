import XCTest

@testable import ContextCore

/// A failed whiteboard sync tries again by itself, waiting longer each time (#1002, story 347).
final class BoardSyncRetryTests: XCTestCase {
  func testTheWaitDoublesFromFifteenSecondsToFiveMinutes() {
    var retry = BoardSyncRetry()
    let waits = (0..<8).map { _ in retry.failed() }
    XCTAssertEqual(waits, [15, 30, 60, 120, 240, 300, 300, 300])
    XCTAssertEqual(retry.failures, 8)
  }

  func testCloudKitsOwnWaitIsNeverCutShort() {
    var retry = BoardSyncRetry()
    XCTAssertEqual(retry.failed(retryAfter: 2.5), 15, "a shorter ask still waits the backoff")
    XCTAssertEqual(retry.failed(retryAfter: 900), 900, "a longer ask waits as long as CloudKit said")
  }

  func testASyncThatGetsThroughStartsOver() {
    var retry = BoardSyncRetry()
    _ = retry.failed()
    _ = retry.failed()
    retry.succeeded()
    XCTAssertEqual(retry.failures, 0)
    XCTAssertEqual(retry.failed(), 15)
  }

  func testTheFailureCarriesTheLongestRetryAfter() {
    let short = NSError(domain: "CKErrorDomain", code: 22, userInfo: ["CKRetryAfter": 2.5])
    let long = NSError(domain: "CKErrorDomain", code: 7, userInfo: ["CKRetryAfter": NSNumber(value: 30)])
    let failure = BoardSyncFailure(
      why: "open", step: .upload, pending: 1, firstOfLaunch: true, error: short, deleteError: long)
    XCTAssertEqual(failure.retryAfter, 30)
    XCTAssertNil(
      BoardSyncFailure(
        why: "open", step: .list, pending: 0, firstOfLaunch: false,
        error: NSError(domain: "CKErrorDomain", code: 4)
      ).retryAfter)
  }
}
