import XCTest

@testable import ContextCore

/// A failed whiteboard sync's log line (#1002), fed CloudKit errors as the `NSError`s they bridge to.
final class BoardSyncFailureTests: XCTestCase {
  func cloud(_ code: Int, server: String? = nil, extra: [String: Any] = [:]) -> NSError {
    var info = extra
    if let server { info["ServerErrorDescription"] = server }
    return NSError(domain: "CKErrorDomain", code: code, userInfo: info)
  }

  func testAnAtomicRollbackOnUploadNamesTheSiblingThatFailed() {
    let atomic = cloud(22, server: "Atomic failure", extra: ["CKRetryAfter": 2.5])
    let gone = cloud(11, server: "Record not found")
    let fields = BoardSyncFailure(
      why: "open", step: .upload, board: "302d5345", strokes: 41, pending: 2, firstOfLaunch: true, error: atomic,
      saveError: atomic, deleteError: gone
    ).fields

    XCTAssertEqual(fields["ok"] as? Bool, false)
    XCTAssertEqual(fields["why"] as? String, "open")
    XCTAssertEqual(fields["step"] as? String, "upload")
    XCTAssertEqual(fields["board"] as? String, "302d5345")
    XCTAssertEqual(fields["strokes"] as? Int, 41)
    XCTAssertEqual(fields["pending"] as? Int, 2)
    XCTAssertEqual(fields["first_of_launch"] as? Bool, true)
    XCTAssertEqual(fields["code"] as? Int, 22)
    XCTAssertEqual(fields["retry_after"] as? Double, 2.5)
    let save = fields["save_error"] as? [String: Any]
    XCTAssertEqual(save?["code"] as? Int, 22)
    XCTAssertEqual(save?["server"] as? String, "Atomic failure")
    XCTAssertNil(save?["domain"], "CloudKit's own domain goes without saying")
    let delete = fields["delete_error"] as? [String: Any]
    XCTAssertEqual(delete?["code"] as? Int, 11)
    XCTAssertEqual(delete?["server"] as? String, "Record not found")
    XCTAssertNil(fields["partial"])
    XCTAssertNil(fields["zone_error"])
  }

  func testAPartialFailureListsEachRecordsOwnError() {
    let partial = cloud(
      2,
      extra: [
        "CKPartialErrors": [
          AnyHashable("board-a"): cloud(22, server: "Atomic failure"),
          AnyHashable("board-a~deleted"): cloud(14, server: "oplock"),
        ]
      ])
    let fields = BoardSyncFailure(
      why: "foreground", step: .delete, board: "board-a", pending: 0, firstOfLaunch: false, error: partial
    ).fields

    XCTAssertEqual(fields["step"] as? String, "delete")
    XCTAssertEqual(fields["first_of_launch"] as? Bool, false)
    XCTAssertNil(fields["strokes"])
    XCTAssertNil(fields["retry_after"])
    let byRecord = fields["partial"] as? [String: Any]
    XCTAssertEqual((byRecord?["board-a"] as? [String: Any])?["code"] as? Int, 22)
    XCTAssertEqual((byRecord?["board-a~deleted"] as? [String: Any])?["server"] as? String, "oplock")
  }

  func testAFailedListingCarriesTheZoneResultTheSyncWentOnWithout() {
    let network = NSError(domain: NSURLErrorDomain, code: -1009)
    let fields = BoardSyncFailure(
      why: "pull", step: .list, pending: 1, firstOfLaunch: true, error: cloud(4),
      zoneError: network
    ).fields

    XCTAssertEqual(fields["step"] as? String, "list")
    XCTAssertNil(fields["board"])
    XCTAssertNil(fields["save_error"])
    let zone = fields["zone_error"] as? [String: Any]
    XCTAssertEqual(zone?["code"] as? Int, -1009)
    XCTAssertEqual(zone?["domain"] as? String, NSURLErrorDomain)
  }

  func testAFailedDownloadBlamesNoBoardTheEarlierStepsWrote() {
    let fields = BoardSyncFailure(
      why: "open", step: .download, board: "last-uploaded", strokes: 7, pending: 1, firstOfLaunch: false,
      error: cloud(4)
    ).fields

    XCTAssertEqual(fields["step"] as? String, "download")
    XCTAssertNil(fields["board"])
    XCTAssertNil(fields["strokes"])
  }

  func testTheFieldsAreJSONTheSessionLogCanWrite() {
    let fields = BoardSyncFailure(
      why: "open", step: .upload, board: "a", strokes: 1, pending: 1, firstOfLaunch: true,
      error: cloud(22, server: "Atomic failure"), saveError: cloud(22), deleteError: cloud(11)
    ).fields
    XCTAssertTrue(JSONSerialization.isValidJSONObject(fields))
  }
}
