import XCTest

@testable import ContextCore

/// A board's thread refused by iCloud's production side (bead context-grabber-irm0, story 1117): the board goes up
/// once more without it, and no thread is offered again that launch.
final class BoardThreadRefusalTests: XCTestCase {
  func cloud(_ code: Int, server: String? = nil, extra: [String: Any] = [:]) -> NSError {
    var info = extra
    if let server { info["ServerErrorDescription"] = server }
    return NSError(domain: "CKErrorDomain", code: code, userInfo: info)
  }

  func testInvalidArgumentsOnABoardCarryingAThreadIsRetriedWithoutIt() {
    let refused = cloud(
      12, server: "Cannot create or modify field 'thread' in record 'WhiteboardBoard' in production schema")
    XCTAssertTrue(BoardThreadRefusal.retryWithoutThread(refused, sentThread: true))
    XCTAssertTrue(
      BoardThreadRefusal.retryWithoutThread(cloud(12), sentThread: true),
      "the code alone: the server's wording is unobserved")
  }

  func testABoardWithNoThreadIsNeverRetried() {
    XCTAssertFalse(BoardThreadRefusal.retryWithoutThread(cloud(12), sentThread: false))
  }

  func testOtherFailuresThrowAsBefore() {
    XCTAssertFalse(BoardThreadRefusal.retryWithoutThread(cloud(4, server: "Network failure"), sentThread: true))
    XCTAssertFalse(BoardThreadRefusal.retryWithoutThread(cloud(22, server: "Atomic failure"), sentThread: true))
    XCTAssertFalse(
      BoardThreadRefusal.retryWithoutThread(NSError(domain: "NSURLErrorDomain", code: 12), sentThread: true),
      "a 12 from another domain is not CloudKit's")
  }

  func testAProductionSchemaMessageUnderAnotherCodeIsRetried() {
    let rejected = cloud(15, server: "Cannot create new field 'thread' in production schema")
    XCTAssertTrue(BoardThreadRefusal.retryWithoutThread(rejected, sentThread: true))
  }

  func testAPartialFailureCarryingTheRefusalIsRetried() {
    let partial = cloud(2, extra: ["CKPartialErrors": [AnyHashable("board-a"): cloud(12)]])
    XCTAssertTrue(BoardThreadRefusal.retryWithoutThread(partial, sentThread: true))
    let other = cloud(2, extra: ["CKPartialErrors": [AnyHashable("board-a"): cloud(14, server: "oplock")]])
    XCTAssertFalse(BoardThreadRefusal.retryWithoutThread(other, sentThread: true))
  }

  func testOnceRefusedABoardWaitingOnlyOnItsThreadIsNotSentAgainThatLaunch() {
    var index = BoardIndex(boards: [
      BoardEntry(id: "a", title: "A", created: 1, updated: 5, strokes: 1, device: "ipad", deviceName: "iPad"),
      BoardEntry(id: "b", title: "B", created: 1, updated: 5, strokes: 1, device: "ipad", deviceName: "iPad"),
    ])
    let threads = ["a": "t1"]
    var launch = BoardThreadRefusal()
    XCTAssertEqual(index.pendingUploads(device: "ipad", threads: launch.offered(threads)).map(\.id), ["a", "b"])

    // "a" was refused for its thread and went up without it; "b" had none.
    launch.dropped()
    index.uploaded("a", at: 5, thread: nil)
    index.uploaded("b", at: 5)
    XCTAssertEqual(index.pendingUploads(device: "ipad", threads: launch.offered(threads)), [], "no resend every sync")

    // New ink still goes up, without the thread.
    let drawnOn = BoardIndex(boards: [
      BoardEntry(
        id: "a", title: "A", created: 1, updated: 6, strokes: 2, device: "ipad", deviceName: "iPad", uploaded: 5)
    ])
    XCTAssertEqual(drawnOn.pendingUploads(device: "ipad", threads: launch.offered(threads)).map(\.id), ["a"])

    // The next launch offers the thread again, so it goes up once production has the field.
    let next = BoardThreadRefusal()
    XCTAssertEqual(index.pendingUploads(device: "ipad", threads: next.offered(threads)).map(\.id), ["a"])
    index.uploaded("a", at: 5, thread: "t1")
    XCTAssertEqual(index.pendingUploads(device: "ipad", threads: next.offered(threads)), [])
  }
}
