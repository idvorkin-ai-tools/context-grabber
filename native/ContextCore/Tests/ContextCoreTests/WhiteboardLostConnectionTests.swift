//  #1136 (stories 908, 909): a connection lost under Larry's turn gets one quiet second try; a second loss, another error or a
//  turn taken over in the meantime is said as before.

import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private struct Sends {
  var answers: [Result<String, Error>]
  var count = 0

  mutating func next() throws -> String {
    defer { count += 1 }
    return try answers[count].get()
  }
}

private let lost = URLError(.networkConnectionLost)
private let offline = URLError(.notConnectedToInternet)

final class WhiteboardLostConnectionTests: XCTestCase {
  func testALostConnectionIsSentOnceMoreAndSaysNothing() async throws {
    var sends = Sends(answers: [.failure(lost), .success("sent")])
    var record: WhiteboardLostConnection.Record?
    var asked = 0
    let value = try await WhiteboardLostConnection.run(
      "upload", record: &record,
      again: { _ in
        asked += 1
        return true
      }, send: { try sends.next() })
    XCTAssertEqual(value, "sent")
    XCTAssertEqual(sends.count, 2)
    XCTAssertEqual(asked, 1)
    XCTAssertEqual(record?.step, "upload")
    XCTAssertEqual(record?.code, -1005)
    XCTAssertEqual(record?.tried, true)
    XCTAssertEqual(record?.worked, true)
  }

  func testLostTwiceIsSaid() async {
    var sends = Sends(answers: [.failure(lost), .failure(lost), .success("never")])
    var record: WhiteboardLostConnection.Record?
    do {
      _ = try await WhiteboardLostConnection.run(
        "message", record: &record, again: { _ in true }, send: { try sends.next() })
      XCTFail("a second loss is said")
    } catch {
      XCTAssertTrue(WhiteboardLostConnection.isLost(error))
    }
    XCTAssertEqual(sends.count, 2)
    XCTAssertEqual(record?.worked, false)
  }

  func testNoNetworkIsSaidAtOnce() async {
    var sends = Sends(answers: [.failure(offline), .success("never")])
    var record: WhiteboardLostConnection.Record?
    do {
      _ = try await WhiteboardLostConnection.run(
        "upload", record: &record, again: { _ in true }, send: { try sends.next() })
      XCTFail("no network is an outage")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
    XCTAssertEqual(sends.count, 1)
    XCTAssertNil(record)
  }

  func testOneMoreTryPerHandOff() async throws {
    var record: WhiteboardLostConnection.Record?
    var upload = Sends(answers: [.failure(lost), .success("ref")])
    _ = try await WhiteboardLostConnection.run(
      "upload", record: &record, again: { _ in true }, send: { try upload.next() })
    var message = Sends(answers: [.failure(lost), .success("never")])
    do {
      _ = try await WhiteboardLostConnection.run(
        "message", record: &record, again: { _ in true }, send: { try message.next() })
      XCTFail("the hand-off's one more try was used")
    } catch {
      XCTAssertTrue(WhiteboardLostConnection.isLost(error))
    }
    XCTAssertEqual(message.count, 1)
    XCTAssertEqual(record?.step, "upload")
  }

  func testATurnTakenOverIsNotSentAgain() async {
    var sends = Sends(answers: [.failure(lost), .success("never")])
    var record: WhiteboardLostConnection.Record?
    do {
      _ = try await WhiteboardLostConnection.run(
        "upload", record: &record, again: { _ in false }, send: { try sends.next() })
      XCTFail("the loss comes back")
    } catch {
      XCTAssertTrue(WhiteboardLostConnection.isLost(error))
    }
    XCTAssertEqual(sends.count, 1)
    XCTAssertEqual(record?.tried, false)
    XCTAssertEqual(record?.logFields["lost_retried"] as? Bool, false)
    XCTAssertNil(record?.logFields["lost_retry_ok"])
  }
}
