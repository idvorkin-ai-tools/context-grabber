import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Send to new chat (context-grabber-9yo): the request, what each answer means, and the moved line it leaves.
final class ChatMoveTests: XCTestCase {
  private let cockpit = "https://cockpit.example.ts.net:8443/"

  // MARK: The request

  func testTheMoveIsAJSONPostNamingTheChatAndTheMessage() throws {
    let request = try ChatMove.request(thread: "auto:note:2026-11-14", message: "m-1", cockpit: cockpit)
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example.ts.net:8443/chat/move")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cockpit.example.ts.net:8443")
    let body = try XCTUnwrap(request.httpBody)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: String])
    XCTAssertEqual(json, ["thread": "auto:note:2026-11-14", "message_id": "m-1"])
  }

  func testABadAddressThrows() {
    XCTAssertThrowsError(try ChatMove.request(thread: "t", message: "m", cockpit: ""))
  }

  // MARK: The answer

  private func outcome(_ status: Int?, _ body: String = "") -> ChatMove.Outcome {
    ChatMove.outcome(status: status, body: Data(body.utf8))
  }

  func testA200NamesTheNewChatAndItsTitle() {
    XCTAssertEqual(
      outcome(200, #"{"thread": "chat:abc", "title": "Plan the trip"}"#),
      .moved(thread: "chat:abc", title: "Plan the trip"))
    XCTAssertEqual(
      outcome(200, #"{"ok": true, "thread": "chat:abc", "title": ""}"#), .moved(thread: "chat:abc", title: "New chat"))
  }

  func testA200WithNoNewChatIsARefusal() {
    XCTAssertEqual(outcome(200, #"{"ok": true}"#), .refused("the Cockpit's answer named no new chat (HTTP 200)"))
    XCTAssertEqual(outcome(200, "<html>"), .refused("the Cockpit's answer named no new chat (HTTP 200)"))
    XCTAssertEqual(
      outcome(200, #"{"ok": false, "thread": "chat:abc", "error": "busy"}"#), .refused("busy (HTTP 200)"))
  }

  func testA404IsAnUnknownMessageOrAnOlderCockpit() {
    XCTAssertEqual(
      outcome(404, "Not Found"),
      .refused("the Cockpit has no such message here, or can't move messages yet (HTTP 404)"))
    XCTAssertEqual(outcome(404, #"{"error": "unknown message"}"#), .refused("unknown message (HTTP 404)"))
  }

  /// Today's Cockpit takes /chat/move for a message to a chat called "move", with no words.
  func testACockpitFromBeforeTheRouteSaysItCantMoveYet() {
    XCTAssertEqual(
      outcome(400, #"{"ok": false, "error": "chat message needs text"}"#),
      .refused("the Cockpit can't move messages yet, or refused this one: chat message needs text (HTTP 400)"))
    XCTAssertEqual(outcome(400), .refused("the Cockpit can't move messages yet, or refused this one (HTTP 400)"))
  }

  func testA409IsAlreadyMovedOrNotMine() {
    XCTAssertEqual(outcome(409, ""), .refused("it was already moved, or it isn't yours (HTTP 409)"))
    XCTAssertEqual(outcome(409, #"{"error": "already moved"}"#), .refused("already moved (HTTP 409)"))
  }

  func testAnyOtherStatusOrNoAnswerIsARefusal() {
    XCTAssertEqual(outcome(500, ""), .refused("the Cockpit refused it (HTTP 500)"))
    XCTAssertEqual(outcome(415, #"{"error": "not json"}"#), .refused("not json (HTTP 415)"))
    XCTAssertEqual(outcome(nil), .refused("no answer from the Cockpit"))
    XCTAssertEqual(
      ChatMove.outcome(status: nil, body: nil, error: "The network connection was lost."),
      .refused("The network connection was lost."))
  }

  func testTheProblemSaysWhatFailed() {
    XCTAssertEqual(ChatMove.problem("x (HTTP 409)"), "Could not send this to a new chat: x (HTTP 409)")
  }

  // MARK: One move, through a stubbed Cockpit

  @MainActor func testARunSendsOneRequestAndReadsItsAnswer() async throws {
    var sent: [URLRequest] = []
    let moved = await ChatMove.run(thread: "t1", message: "m1", cockpit: cockpit) { request in
      sent.append(request)
      return (Data(#"{"thread": "t2", "title": "Fresh start"}"#.utf8), 200)
    }
    XCTAssertEqual(moved, .moved(thread: "t2", title: "Fresh start"))
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent.first?.url?.path, "/chat/move")
  }

  @MainActor func testARunThatCannotReachTheCockpitIsARefusal() async {
    let failed = await ChatMove.run(thread: "t1", message: "m1", cockpit: cockpit) { _ in
      throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "offline"])
    }
    XCTAssertEqual(failed, .refused("offline"))
  }

  // MARK: The moved line left in the old chat

  private func rows(_ json: String) throws -> [ChatMessage] {
    try XCTUnwrap(ChatWire.messages(Data(json.utf8)))
  }

  func testTheMovedLineNamesItsNewChat() throws {
    let thread = try rows(
      #"""
      {"ok": true, "messages": [
        {"id": "l1", "ts": "2026-11-14T10:00:00-08:00", "who": "larry", "text": "Morning"},
        {"id": "s1", "ts": "2026-11-14T10:01:00-08:00", "who": "system", "text": "Moved to a new chat",
         "moved_to": "chat:new"}
      ]}
      """#)
    XCTAssertEqual(thread.map(\.isSystem), [false, true])
    XCTAssertEqual(thread[1].movedTo, "chat:new")
    XCTAssertEqual(thread[1].text, "Moved to a new chat")
    XCTAssertFalse(thread[1].fromIgor)
  }

  /// The contract names no field for the new chat: either spare spelling is read too.
  func testTheMovedLineReadsTheSpareSpellings() throws {
    let thread = try rows(
      #"""
      {"ok": true, "messages": [
        {"id": "a", "who": "system", "text": "Moved to a new chat", "new_thread": "chat:a"},
        {"id": "b", "who": "system", "text": "Moved to a new chat", "moved_to_thread": "chat:b"},
        {"id": "c", "who": "system", "text": "Moved to a new chat", "moved_to": ""},
        {"id": "d", "who": "igor", "text": "hi"}
      ]}
      """#)
    XCTAssertEqual(thread.map(\.movedTo), ["chat:a", "chat:b", nil, nil])
    XCTAssertEqual(thread.map(\.isSystem), [true, true, true, false])
  }

  /// How the line reads: the Cockpit's words, a link when it names the new chat, plain otherwise; a message is no line.
  func testTheMovedLineReadsAsALinkToTheNewChat() {
    let moved = ChatMessage(id: "s", ts: "", who: "system", text: "Moved to a new chat", movedTo: "chat:new")
    XCTAssertEqual(ChatMove.line(moved), .init(words: "Moved to a new chat", opens: "chat:new"))
    let wordless = ChatMessage(id: "w", ts: "", who: "system", text: " ", movedTo: "chat:new")
    XCTAssertEqual(ChatMove.line(wordless), .init(words: "Moved to a new chat", opens: "chat:new"))
    let unnamed = ChatMessage(id: "u", ts: "", who: "system", text: "Moved to a new chat")
    XCTAssertEqual(ChatMove.line(unnamed), .init(words: "Moved to a new chat", opens: nil))
    XCTAssertNil(ChatMove.line(ChatMessage(id: "i", ts: "", who: "igor", text: "Moved to a new chat")))
    XCTAssertNil(ChatMove.line(ChatMessage(id: "l", ts: "", who: "larry", text: "Hi")))
  }

  /// The moved line is no reply: Igor's message before it, with a failure before that, still shows no 🏆.
  func testTheMovedLineIsNotAnAnswer() {
    let thread = [
      ChatMessage(id: "i1", ts: "", who: "igor", text: "Draw it"),
      ChatMessage(id: "e", ts: "", who: "larry", text: "Board unreadable", author: "Whiteboard", isError: true),
      ChatMessage(id: "s", ts: "", who: "system", text: "Moved to a new chat", movedTo: "chat:new"),
    ]
    XCTAssertEqual(ChatWire.answerFailed(thread), ["i1"])
  }
}
