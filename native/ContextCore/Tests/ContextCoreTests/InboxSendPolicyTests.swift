//  #406, story 269: no offline send, one network-back request, and no overlapping sends.

import XCTest

@testable import ContextCore

final class InboxSendPolicyTests: XCTestCase {
  func testLaunchWaitsForTheFirstPathReading() {
    var policy = InboxSendPolicy()
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: false), .wait)
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: false), .send)
  }

  func testOfflineSkipsEvenWhenASendIsAlreadyOut() {
    var policy = InboxSendPolicy()
    XCTAssertFalse(policy.updatePath(.offline))
    for sending in [false, true] {
      XCTAssertEqual(policy.decision(waitingCount: 2, sending: sending), .offlineSkipped)
    }
  }

  func testNetworkReturnRequestsOnlyOneSendUntilItGoesOfflineAgain() {
    var policy = InboxSendPolicy()
    XCTAssertFalse(policy.updatePath(.offline))
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 3, sending: false), .send)
    XCTAssertFalse(policy.updatePath(.online))
    XCTAssertFalse(policy.updatePath(.online))
    XCTAssertFalse(policy.updatePath(.offline))
    XCTAssertTrue(policy.updatePath(.online))
  }

  func testReturnDuringASendRequestsAnotherPassWhichChecksThePathAgain() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.offline)
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: true), .sendAgain)
    XCTAssertEqual(policy.decision(waitingCount: 3, sending: true), .sendAgain)
    XCTAssertEqual(policy.decision(waitingCount: 1, sending: false), .send)
    _ = policy.updatePath(.offline)
    XCTAssertEqual(policy.decision(waitingCount: 1, sending: false), .offlineSkipped)
  }

  func testNothingWaitingNeverRequestsASend() {
    var policy = InboxSendPolicy()
    for path: InboxSendPolicy.Path in [.unknown, .offline, .online] {
      _ = policy.updatePath(path)
      for sending in [false, true] {
        XCTAssertEqual(policy.decision(waitingCount: 0, sending: sending), .wait)
      }
    }
  }
}
