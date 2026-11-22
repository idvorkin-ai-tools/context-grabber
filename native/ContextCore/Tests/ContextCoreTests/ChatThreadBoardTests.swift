import XCTest

@testable import ContextCore

/// #1091, stories 1122, 1123: which board a thread's *Board* opens.
final class ChatThreadBoardTests: XCTestCase {
  private func message(_ id: String, board: String? = nil) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: board == nil ? "larry" : "igor", text: "", board: board)
  }

  func testTheNewestMessageFromABoardNamesIt() {
    let messages = [message("1", board: "old"), message("2", board: "new"), message("3")]
    XCTAssertEqual(
      ChatThreadBoard.find(thread: "t", messages: messages, deviceThreads: ["mine": "t"]),
      ChatThreadBoard(board: "new", source: .message),
      "a message beats this device's record, and Larry's reply after it doesn't hide it")
  }

  func testAThreadThisDeviceStartedFromABoardIsThatBoards() {
    XCTAssertEqual(
      ChatThreadBoard.find(thread: "t", messages: [message("1")], deviceThreads: ["b2": "t", "b1": "t", "x": "u"]),
      ChatThreadBoard(board: "b1", source: .device), "the same board every time when two once shared a thread")
  }

  /// This device's record, read whole: only the board threads, not other settings beside them.
  func testThisDevicesBoardThreadsReadWhole() throws {
    let suite = "chat-thread-board-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
    let threads = WhiteboardThreads(defaults: defaults)
    threads.set("t1", board: "b1")
    threads.set("t2", board: "b2")
    defaults.set("x", forKey: "something_else")
    XCTAssertEqual(threads.all(), ["b1": "t1", "b2": "t2"])
  }

  func testAThreadWithNoBoardHasNone() {
    XCTAssertNil(ChatThreadBoard.find(thread: "t", messages: [message("1")], deviceThreads: ["b": "u"]))
    XCTAssertNil(
      ChatThreadBoard.find(thread: nil, messages: [], deviceThreads: ["b": "t"]), "a new chat not landed yet")
  }
}
