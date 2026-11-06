import XCTest

@testable import ContextCore

/// A PR chip's state (#736 option C, stories 554 and 728): the refs asked for, the Cockpit's answer, the chip's word.
final class ChatPRStatesTests: XCTestCase {
  private let text = """
    Opened https://github.com/idvorkin/context-grabber/pull/734 and https://github.com/Idvorkin/Context-Grabber/pull/736, \
    the log is https://gist.github.com/idvorkin/3f2a9c1e8b7d, and https://github.com/idvorkin/context-grabber/pull/734/files.
    """

  private var links: [ChatLink] { ChatLinks.found(in: text) }

  func testRefsAreThePRsOnceEachInOrder() {
    XCTAssertEqual(ChatPRStates.refs(links), ["idvorkin/context-grabber#734", "idvorkin/context-grabber#736"])
  }

  func testRefsStopAtTheCockpitsLimit() {
    let many = (1...250).map { "https://github.com/a/b/pull/\($0)" }.joined(separator: " ")
    let refs = ChatPRStates.refs(ChatLinks.found(in: many))
    XCTAssertEqual(refs.count, ChatPRStates.refLimit)
    XCTAssertEqual(refs.first, "a/b#1")
  }

  func testTheRequestNamesTheRefsWithTheHashEncoded() throws {
    let request = try ChatPRStates.request(
      ["idvorkin/context-grabber#734", "idvorkin/chop-conventions#12"], cockpit: "http://cockpit.example:8080/")
    XCTAssertEqual(
      request.url?.absoluteString,
      "http://cockpit.example:8080/pr-states?refs=idvorkin/context-grabber%23734,idvorkin/chop-conventions%2312")
    XCTAssertEqual(request.httpMethod, "GET")
  }

  /// The answer as Larry's contract gives it (2026-11-06), a draft and a pending ref included.
  private let answer = Data(
    """
    {"ok": true, "boot": "b1", "seq": 42,
     "states": {
       "idvorkin/context-grabber#734": {"state": "MERGED", "merged_at": "2026-11-06T10:00:00Z", "closed_at": "2026-11-06T10:00:00Z", "is_draft": false},
       "Idvorkin/Context-Grabber#736": {"state": "OPEN", "merged_at": null, "closed_at": null, "is_draft": false},
       "idvorkin/context-grabber#737": {"state": "OPEN", "merged_at": null, "closed_at": null, "is_draft": true},
       "idvorkin/context-grabber#700": {"state": "CLOSED", "merged_at": null, "closed_at": "2026-11-01T00:00:00Z", "is_draft": false},
       "idvorkin/context-grabber#701": {"state": "SOMETHING_NEW"}
     },
     "tracked": 5, "pending": ["idvorkin/context-grabber#738"]}
    """.utf8)

  func testTheAnswerReadsEachStateADraftAndWhatIsPending() throws {
    let parsed = try XCTUnwrap(ChatPRStates.parse(answer))
    XCTAssertEqual(
      parsed.states,
      [
        "idvorkin/context-grabber#734": .merged, "idvorkin/context-grabber#736": .open,
        "idvorkin/context-grabber#737": .draft, "idvorkin/context-grabber#700": .closed,
      ])
    XCTAssertTrue(parsed.pending)
  }

  func testNothingPendingAndNotOk() throws {
    let none = Data(#"{"ok": true, "states": {}, "tracked": 0, "pending": []}"#.utf8)
    XCTAssertEqual(ChatPRStates.parse(none), ChatPRStates.Answer(states: [:], pending: false))
    XCTAssertEqual(ChatPRStates.parse(Data(#"{"ok": true, "states": {}, "pending": 2}"#.utf8))?.pending, true)
    XCTAssertNil(ChatPRStates.parse(Data(#"{"ok": false, "error": "too many refs"}"#.utf8)))
    XCTAssertNil(ChatPRStates.parse(Data("<html>502</html>".utf8)))
  }

  func testTheChipsGainTheirWordsAndAnUnknownPRReadsAsToday() throws {
    let states = try XCTUnwrap(ChatPRStates.parse(answer)).states
    let applied = ChatPRStates.applied(states, to: ChatLinks.found(in: text + " https://github.com/a/b/pull/9"))
    XCTAssertEqual(applied.map(\.chipText), ["PR #734 merged", "PR #736 open", "gist", "PR #734 merged", "PR #9"])
    XCTAssertEqual(applied.map(\.state), [.merged, .open, nil, .merged, nil])
  }

  func testAStateTheCockpitNoLongerReportsIsCleared() {
    var link = links[0]
    link.state = .open
    XCTAssertNil(ChatPRStates.applied([:], to: [link])[0].state)
  }
}
