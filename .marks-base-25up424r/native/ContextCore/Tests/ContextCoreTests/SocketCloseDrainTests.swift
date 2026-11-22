import XCTest

@testable import ContextCore

/// #902: hanging up lets the stop frames leave before the socket closes, and never waits forever.
final class SocketCloseDrainTests: XCTestCase {
  private var scheduler = FakeScheduler()
  private var outcomes: [SocketCloseDrain.Outcome] = []

  override func setUp() {
    scheduler = FakeScheduler()
    outcomes = []
  }

  private func drain() -> SocketCloseDrain { SocketCloseDrain(scheduler: scheduler) }

  func testNothingInFlightClosesAtOnce() {
    let d = drain()
    d.close { self.outcomes.append($0) }
    XCTAssertEqual(outcomes, [.init(drained: true, pending: 0, waitedMs: 0)])
  }

  func testTheCloseWaitsForTheStopFramesToLeave() {
    let d = drain()
    d.sending()  // the dump
    d.sending()  // stt_stop
    d.sending()  // stop
    d.close { self.outcomes.append($0) }
    XCTAssertTrue(outcomes.isEmpty, "closed with the stop frames still queued")
    scheduler.advance(50)
    d.completed()
    d.completed()
    XCTAssertTrue(outcomes.isEmpty)
    scheduler.advance(30)
    d.completed()
    XCTAssertEqual(outcomes, [.init(drained: true, pending: 0, waitedMs: 80)])
  }

  func testASendThatNeverFinishesClosesAfterTheBound() {
    let d = drain()
    d.sending()
    d.sending()
    d.close { self.outcomes.append($0) }
    d.completed()
    scheduler.advance(SocketCloseDrain.defaultBoundMs - 1)
    XCTAssertTrue(outcomes.isEmpty)
    scheduler.advance(1)
    XCTAssertEqual(outcomes, [.init(drained: false, pending: 1, waitedMs: SocketCloseDrain.defaultBoundMs)])
  }

  func testItClosesExactlyOnce() {
    let d = drain()
    d.sending()
    d.close { self.outcomes.append($0) }
    d.close { self.outcomes.append($0) }
    d.completed()
    scheduler.advance(SocketCloseDrain.defaultBoundMs * 2)
    d.completed()
    XCTAssertEqual(outcomes.count, 1)
    XCTAssertTrue(d.closed)
  }

  func testSendsThatFinishBeforeTheHangUpDoNotHoldItUp() {
    let d = drain()
    d.sending()
    d.completed()
    d.close { self.outcomes.append($0) }
    XCTAssertEqual(outcomes.first?.drained, true)
  }
}
