import XCTest

@testable import ContextCore

/// Story 1608 (#1362): a thread says *Loading this chat…* while its first read is on its way, and only then.
final class ChatThreadLoadingTests: XCTestCase {
  private func shows(
    thread: Bool = true, read: Bool = false, pending: Int = 0, problem: Bool = false, offline: Bool = false
  ) -> Bool {
    ChatThreadLoading.shows(thread: thread, read: read, pending: pending, problem: problem, offline: offline)
  }

  func testAThreadNotYetReadSaysItIsLoading() {
    XCTAssertTrue(shows())
  }

  func testNothingToLoadSaysNothing() {
    XCTAssertFalse(shows(thread: false), "a new chat from the + has nothing to read")
    XCTAssertFalse(shows(read: true), "its messages are on screen")
    XCTAssertFalse(shows(pending: 1), "Igor's own message is on screen")
    XCTAssertFalse(shows(problem: true), "the banner says what happened instead")
    XCTAssertFalse(shows(offline: true), "the device offline keeps its own No network line")
  }

  func testTheWords() {
    XCTAssertEqual(ChatThreadLoading.words, "Loading this chat…")
  }
}
