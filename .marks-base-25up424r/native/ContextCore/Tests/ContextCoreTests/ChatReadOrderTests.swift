import ContextCore
import Foundation
import XCTest

/// Bead context-grabber-exg6: a stopped read shows nothing, and an older read never replaces a newer one.
final class ChatReadOrderTests: XCTestCase {
  func testOneReadShows() {
    var order = ChatReadOrder()
    let read = order.start()
    XCTAssertTrue(order.mayShow(read))
  }

  func testAnOlderReadFinishingLastDoesNotShow() {
    var order = ChatReadOrder()
    let older = order.start()  // the app coming to the front
    let newer = order.start()  // the list opening
    XCTAssertTrue(order.mayShow(newer))
    XCTAssertFalse(order.mayShow(older), "the older answer or problem would replace the newer list")
  }

  func testReadsFinishingInOrderBothShow() {
    var order = ChatReadOrder()
    let older = order.start()
    let newer = order.start()
    XCTAssertTrue(order.mayShow(older))
    XCTAssertTrue(order.mayShow(newer))
  }

  func testAnOlderReadShowsWhenTheNewerOneWasStopped() {
    var order = ChatReadOrder()
    let older = order.start()
    _ = order.start()  // stopped: never asks
    XCTAssertTrue(order.mayShow(older), "a stopped read must not hide the one before it")
  }

  func testATicketShowsOnce() {
    var order = ChatReadOrder()
    let read = order.start()
    XCTAssertTrue(order.mayShow(read))
    XCTAssertFalse(order.mayShow(read))
  }

  func testCancellationIsNotAFailure() {
    XCTAssertTrue(ChatReadOrder.isCancellation(CancellationError()))
    XCTAssertTrue(ChatReadOrder.isCancellation(URLError(.cancelled)))
    XCTAssertFalse(ChatReadOrder.isCancellation(URLError(.timedOut)))
    XCTAssertFalse(ChatReadOrder.isCancellation(URLError(.badServerResponse)))
  }
}
