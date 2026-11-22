import Foundation
import XCTest

@testable import ContextCore

/// Story 929 (context-grabber-4fww): the Cockpit's hold on Igor's newest message, decoded from its JSON, and the ear the
/// board shows for it.
final class WhiteboardLarryListeningTests: XCTestCase {
  private let t0 = ContinuousClock.now

  /// The Cockpit's shape (f6b83dd), and the ones it must survive.
  func testTheHoldDecodesAndNeverCostsTheReceipt() throws {
    let json = #"""
      {"ok": true, "messages": [
        {"id": "a", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "received_ts": "x",
         "seen_ts": "y", "waiting": {"label": "Larry: hmm, go on", "ts": "2026-11-22T15:00:00-08:00"}}},
        {"id": "b", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "seen_ts": "y"}},
        {"id": "c", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "waiting": {}}},
        {"id": "d", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "waiting": {"label": "  "}}},
        {"id": "e", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "waiting": "yes"}},
        {"id": "f", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "waiting": {"label": 7}}},
        {"id": "g", "ts": "", "who": "igor", "text": "", "receipt": {"state": "holding", "waiting": {"ts": "z"}}},
        {"id": "h", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "waiting": null}}
      ]}
      """#
    let messages = try XCTUnwrap(ChatWire.messages(Data(json.utf8)))
    XCTAssertEqual(messages.map(\.receipt), [.seen, .seen, .seen, .seen, .seen, .seen, .received, .seen])
    XCTAssertEqual(
      messages.map { $0.waiting?.label },
      [
        "Larry: hmm, go on", nil, ChatMessage.Waiting.defaultLabel, ChatMessage.Waiting.defaultLabel, nil,
        ChatMessage.Waiting.defaultLabel, ChatMessage.Waiting.defaultLabel, nil,
      ])
    XCTAssertEqual(messages[0].waiting?.ts, "2026-11-22T15:00:00-08:00")
    XCTAssertEqual(ChatMessage.Waiting.defaultLabel, "Larry: waiting for more")
  }

  private func igor(_ id: String, waiting: String? = nil, ts: String = "") -> ChatMessage {
    ChatMessage(
      id: id, ts: ts, who: "igor", text: "", receipt: .seen,
      waiting: waiting.map { ChatMessage.Waiting(label: $0) })
  }

  private func larry(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "larry", text: "go on") }

  func testOnlyIgorsNewestMessageWithNoReplyAfterItHolds() {
    XCTAssertEqual(
      WhiteboardLarryListening.label(in: [larry("1"), igor("2", waiting: "Larry: go on")]), "Larry: go on")
    XCTAssertNil(WhiteboardLarryListening.label(in: [igor("1", waiting: "x"), igor("2")]), "an older hold is stale")
    XCTAssertNil(WhiteboardLarryListening.label(in: [igor("1", waiting: "x"), larry("2")]), "he answered")
    XCTAssertNil(WhiteboardLarryListening.label(in: []))
    XCTAssertNil(WhiteboardLarryListening.label(in: [larry("1")]))
    let system = ChatMessage(id: "s", ts: "", who: "system", text: "Moved to a new chat")
    XCTAssertEqual(
      WhiteboardLarryListening.label(in: [igor("1", waiting: "x"), system]), "x", "a Cockpit line isn't him")
  }

  func testAHoldOnTheTurnsPictureIsHisAnswer() {
    var turn = WhiteboardLarryTurn()
    XCTAssertFalse(
      WhiteboardLarryListening.holdsTurn(turn, thread: [igor("p", waiting: "x")], picture: "p", went: Date()),
      "no turn out")
    _ = turn.tapped(version: 1, now: t0)
    XCTAssertTrue(
      WhiteboardLarryListening.holdsTurn(turn, thread: [igor("p", waiting: "x")], picture: "p", went: Date()))
    XCTAssertFalse(
      WhiteboardLarryListening.holdsTurn(turn, thread: [igor("old", waiting: "x")], picture: "p", went: Date()),
      "a hold on an earlier message, the picture not on the thread yet")
    XCTAssertFalse(WhiteboardLarryListening.holdsTurn(turn, thread: [igor("p")], picture: "p", went: Date()))
    // A Send to Larry: no id, so Igor's newest message since the picture went.
    let went = Date(timeIntervalSince1970: 1_800_000_000)
    let after = igor("s", waiting: "x", ts: "2027-01-15T08:00:00Z")
    let before = igor("s", waiting: "x", ts: "2020-01-01T00:00:00Z")
    XCTAssertTrue(WhiteboardLarryListening.holdsTurn(turn, thread: [after], picture: nil, went: went))
    XCTAssertFalse(WhiteboardLarryListening.holdsTurn(turn, thread: [before], picture: nil, went: went))
  }

  func testTheEarShowsOnlyWithNoTurnOutAndReplacesTheChipsWord() {
    var turn = WhiteboardLarryTurn()
    let thread = [
      ChatMessage(
        id: "p", ts: "", who: "igor", text: "", attachments: ["a.png"], receipt: .seen,
        waiting: ChatMessage.Waiting())
    ]
    let line = WhiteboardNote.line(
      larry: turn, now: t0, cockpitAnswering: true, said: WhiteboardSaid(), micOn: false, notice: nil, ghosts: 0,
      listening: "Larry: waiting for more")
    XCTAssertEqual(line?.listening, "Larry: waiting for more", "a line with only the ear still shows")
    XCTAssertNil(line?.state)
    let live = WhiteboardNote.live(
      thread: thread, larry: turn, now: t0, cockpitAnswering: true, said: WhiteboardSaid(), micOn: false,
      listening: "Larry: waiting for more")
    XCTAssertEqual(
      live,
      [
        WhiteboardNote.Row(
          id: "live-chip", kind: .live, who: "Your board", text: "Larry: waiting for more", listening: true)
      ])
    XCTAssertEqual(
      WhiteboardNote.live(
        thread: thread, larry: turn, now: t0, cockpitAnswering: true, said: WhiteboardSaid(), micOn: false
      )
      .first?.text, "Larry has it", "no hold: the chip as before")
    _ = turn.tapped(version: 2, now: t0)
    let looking = WhiteboardNote.line(
      larry: turn, now: t0, cockpitAnswering: true, said: WhiteboardSaid(), micOn: false, notice: nil, ghosts: 0,
      listening: "Larry: waiting for more")
    XCTAssertNil(looking?.listening, "a turn out: its clock speaks, not the ear")
    XCTAssertNotNil(looking?.state)
    let chip = WhiteboardNote.live(
      thread: thread, larry: turn, now: t0, cockpitAnswering: true, said: WhiteboardSaid(), micOn: false,
      listening: "Larry: waiting for more"
    ).first
    XCTAssertEqual(chip?.listening, false)
  }
}
