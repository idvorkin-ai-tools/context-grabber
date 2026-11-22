import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Decision cards in Chat (#878, stories 830-833): the Cockpit's open asks as the app reads them, the four verbs'
/// requests, what each answer means, which chats carry a card, and the card's lines.
final class ChatDecisionsTests: XCTestCase {
  private let cockpit = "https://cockpit.example.ts.net:8443/"

  private func fixture() throws -> [ChatAsk] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
      "Fixtures/asks-open.json")
    return try XCTUnwrap(ChatDecisions.asks(try Data(contentsOf: url)))
  }

  private func body(_ request: URLRequest) throws -> NSDictionary {
    let data = try XCTUnwrap(request.httpBody)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  // MARK: Reading the asks

  func testTheOpenAsksReadAsTheCockpitSendsThemInItsOrder() throws {
    let asks = try fixture()
    XCTAssertEqual(asks.map(\.id), ["igor2-88g.2001", "igor2-88g.2002", "igor2-88g.2003"], "the Cockpit's queue order")
    let walk = asks[0]
    XCTAssertEqual(walk.title, "Saturday: which walk?")
    XCTAssertEqual(walk.context, "You said you wanted to get outside this weekend.\n\nThe forecast is dry until 2 pm.")
    XCTAssertEqual(walk.options.map(\.key), ["walk", "hill", "skip"])
    XCTAssertEqual(walk.options[1].label, "The hill")
    XCTAssertEqual(walk.options[1].detail, "an hour, steep")
    XCTAssertEqual(walk.updatedAt, "2026-11-13T02:00:25Z")
    XCTAssertEqual(walk.expiresAt, ChatWire.date("2026-11-15T02:00:25Z"))
    XCTAssertFalse(walk.expired)
    XCTAssertTrue(asks[1].expired)
    XCTAssertNil(asks[2].expiresAt, "no expiry is none, not a made-up one")
  }

  func testAnAnswerThatIsNotAnAskListIsNil() {
    XCTAssertNil(ChatDecisions.asks(Data(#"{"ok": false, "error": "bd: database is locked"}"#.utf8)))
    XCTAssertNil(ChatDecisions.asks(Data("<html>".utf8)))
    XCTAssertEqual(ChatDecisions.asks(Data(#"{"ok": true, "asks": []}"#.utf8)), [])
  }

  func testAnAskMissingItsOptionalFieldsStillReads() throws {
    let asks = try XCTUnwrap(
      ChatDecisions.asks(Data(#"{"ok": true, "asks": [{"id": "b-1", "options": [{"label": "Yes"}]}]}"#.utf8)))
    XCTAssertEqual(asks.first?.title, "b-1")
    XCTAssertEqual(asks.first?.options.first?.key, "opt1", "keyed as the Cockpit keys an option with none")
    XCTAssertNil(asks.first?.marked)
  }

  func testTheDefaultIsMarkedOrElseTheRecommendation() throws {
    let asks = try fixture()
    XCTAssertEqual(asks[0].marked, ChatAsk.Mark(key: "walk", word: "Default"))
    XCTAssertNil(asks[1].marked, "neither: nothing marked")
    XCTAssertEqual(asks[2].marked, ChatAsk.Mark(key: "opt2", word: "Recommended"))
  }

  func testTheListIsAPlainGetOfTheOpenAsks() throws {
    let request = try ChatDecisions.listRequest(cockpit: cockpit)
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example.ts.net:8443/asks")
    XCTAssertEqual(request.httpMethod ?? "GET", "GET")
  }

  // MARK: Which chats carry a card

  private func thread(_ key: String, pinned: Bool = false, skill: String? = nil) -> ChatSummary {
    ChatSummary(key: key, title: key, lastTs: "", lastWho: "larry", lastText: "", pinned: pinned, skill: skill)
  }

  func testAChatCarriesTheAskThatContinuesIt() throws {
    let asks = try fixture()
    XCTAssertEqual(asks.map(\.chat), ["igor2-88g.1999", nil, "igor2-88g.2003"], "the Cockpit's thread, null as none")
    let threads = [
      thread("igor2-88g.1268", pinned: true), thread("igor2-88g.1999"), thread("igor2-88g.2001"),
      thread("igor2-88g.2002"), thread("igor2-88g.2003"), thread("igor2-88g.900"),
    ]
    XCTAssertEqual(
      ChatDecisions.waiting(threads, asks: asks), ["igor2-88g.1999", "igor2-88g.2003"],
      "the parent's chat and the ask's own; a null thread is no chat, even with one on the ask's own bead")
    XCTAssertEqual(ChatDecisions.ask(on: "igor2-88g.1999", in: asks)?.title, "Saturday: which walk?")
    XCTAssertNil(ChatDecisions.ask(on: "igor2-88g.2001", in: asks), "named another chat: not its own")
    XCTAssertNil(ChatDecisions.ask(on: "igor2-88g.2002", in: asks))
    XCTAssertNil(ChatDecisions.ask(on: "igor2-88g.900", in: asks))
    XCTAssertEqual(ChatDecisions.waiting(threads, asks: []), [])
  }

  func testAnOlderCockpitWithNoThreadJoinsAnAskToItsOwnBeadsChat() throws {
    let asks = try XCTUnwrap(
      ChatDecisions.asks(Data(#"{"ok": true, "asks": [{"id": "igor2-88g.2001", "title": "Old"}]}"#.utf8)))
    XCTAssertNil(asks[0].thread)
    XCTAssertEqual(asks[0].chat, "igor2-88g.2001", "no thread key at all: the ask's own bead, as before")
    XCTAssertEqual(ChatDecisions.waiting([thread("igor2-88g.2001")], asks: asks), ["igor2-88g.2001"])
  }

  func testOpenChatOpensTheChatTheAskContinuesOrElseItsOwn() throws {
    let asks = try fixture()
    XCTAssertEqual(asks.map(\.chatToOpen), ["igor2-88g.1999", "igor2-88g.2002", "igor2-88g.2003"])
  }

  func testTwoAsksOnOneChatShowTheFirstInTheCockpitsOrder() throws {
    let asks = try XCTUnwrap(
      ChatDecisions.asks(
        Data(
          #"{"ok": true, "asks": [{"id": "b-2", "title": "Second", "thread": "chat-1"}, {"id": "b-3", "title": "Third", "thread": "chat-1"}]}"#
            .utf8)))
    XCTAssertEqual(ChatDecisions.ask(on: "chat-1", in: asks)?.id, "b-2")
    XCTAssertEqual(ChatDecisions.ask(on: "chat-1", in: Array(asks.dropFirst()))?.id, "b-3", "then the next")
  }

  func testTheDecisionsRowSitsUnderLarrysPinnedThread() {
    let larry = thread("igor2-88g.1268", pinned: true)
    let skill = thread("igor2-88g.632", pinned: true, skill: "idvorkin")
    XCTAssertEqual(ChatDecisions.rowAfter([larry, skill, thread("a")]), "igor2-88g.1268")
    XCTAssertNil(ChatDecisions.rowAfter([skill, thread("a")]), "no Larry's thread: first in the list")
    XCTAssertNil(ChatDecisions.rowAfter([]))
  }

  // MARK: The verbs' requests

  private func post(_ verb: ChatDecisions.Verb) throws -> URLRequest {
    let ask = try fixture()[0]
    let request = try ChatDecisions.request(verb, ask: ask, cockpit: cockpit)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cockpit.example.ts.net:8443")
    return request
  }

  func testAnAnswerIsTheCockpitCardsOwnDecisionGuardedByTheRevision() throws {
    let option = try fixture()[0].options[1]
    let request = try post(.answer(option))
    XCTAssertEqual(request.url?.path, "/act")
    XCTAssertEqual(
      try body(request),
      [
        "id": "igor2-88g.2001", "action": "respond", "response": "DECISION: The hill",
        "base_updated_at": "2026-11-13T02:00:25Z", "post_to_chat": true, "source": "app",
      ])
    let raw = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
    XCTAssertTrue(raw.contains(#""post_to_chat":true"#), "the literal true, not 1 or \"true\": \(raw)")
  }

  func testACloseNeedsItsReasonAndAnAbandonMayHaveNone() throws {
    let close = try post(.close(reason: "  Booked it  "))
    XCTAssertEqual(close.url?.path, "/close")
    XCTAssertEqual(
      try body(close),
      [
        "id": "igor2-88g.2001", "action": "close", "reason": "Booked it", "base_updated_at": "2026-11-13T02:00:25Z",
        "post_to_chat": true, "source": "app",
      ])
    XCTAssertEqual(
      try body(try post(.abandon(reason: nil))),
      [
        "id": "igor2-88g.2001", "action": "abandon", "reason": "", "base_updated_at": "2026-11-13T02:00:25Z",
        "post_to_chat": true, "source": "app",
      ])
    XCTAssertEqual(try body(try post(.abandon(reason: "Stale")))["reason"] as? String, "Stale")
    XCTAssertFalse(ChatDecisions.canClose(reason: "   "))
    XCTAssertTrue(ChatDecisions.canClose(reason: "done"))
  }

  func testASnoozeNamesTheCockpitsPreset() throws {
    let request = try post(.snooze(.nextWeek))
    XCTAssertEqual(request.url?.path, "/snooze")
    XCTAssertEqual(try body(request), ["id": "igor2-88g.2001", "preset": "next_week"], "a snooze writes no chat row")
    XCTAssertEqual(ChatDecisions.Snooze.allCases.map(\.rawValue), ["later", "tomorrow", "next_week"])
    XCTAssertEqual(ChatDecisions.Snooze.allCases.map(\.label), ["Later today", "Tomorrow morning", "Next week"])
    XCTAssertEqual(
      ChatDecisions.abandonReasons, ["Doesn't matter anymore", "Stale", "Already handled", "Not now"],
      "the Cockpit's presets")
  }

  func testABadAddressThrows() throws {
    let ask = try fixture()[0]
    XCTAssertThrowsError(try ChatDecisions.request(.snooze(.later), ask: ask, cockpit: ""))
    XCTAssertThrowsError(try ChatDecisions.listRequest(cockpit: ""))
  }

  // MARK: What the answer means

  private func outcome(_ status: Int?, _ body: String = "") -> ChatDecisions.Outcome {
    ChatDecisions.outcome(status: status, body: Data(body.utf8))
  }

  func testA200IsDoneAndASnoozeSaysUntilWhen() {
    XCTAssertEqual(
      outcome(200, #"{"ok": true, "id": "b", "action": "respond", "title": "t"}"#), .done(snoozedUntil: nil))
    XCTAssertEqual(
      outcome(200, #"{"ok": true, "id": "b", "snoozed_until": "2026-11-16T16:00:00Z"}"#),
      .done(snoozedUntil: "2026-11-16T16:00:00Z"))
    XCTAssertEqual(outcome(200, #"{"ok": false, "error": "busy"}"#), .refused("busy (HTTP 200)"))
    XCTAssertEqual(outcome(200, "<html>"), .refused("the Cockpit refused it (HTTP 200)"))
  }

  func testA200SaysWhetherTheAnswerWentIntoTheChat() {
    XCTAssertEqual(
      outcome(
        200,
        #"{"ok": true, "id": "b", "action": "respond", "chat": {"posted": true, "thread": "chat-1", "message": {"id": "act-1", "who": "igor", "text": "Decided: A"}, "duplicate": false}}"#
      ),
      .done(snoozedUntil: nil, chat: .init(posted: true, thread: "chat-1", error: nil)))
    XCTAssertEqual(
      outcome(
        200,
        #"{"ok": true, "id": "b", "action": "respond", "chat": {"posted": false, "thread": null, "error": "the ask has no chat thread"}}"#
      ),
      .done(snoozedUntil: nil, chat: .init(posted: false, thread: nil, error: "the ask has no chat thread")))
    XCTAssertEqual(
      outcome(200, #"{"ok": true, "id": "b", "action": "respond"}"#), .done(snoozedUntil: nil, chat: nil),
      "an older Cockpit says nothing about the chat")
  }

  func testTheCardGivesWayToIgorsMessageOnlyInAThreadTheCockpitWroteTo() throws {
    let option = try fixture()[0].options[0]
    let posted = ChatDecisions.Posted(posted: true, thread: "chat-1", error: nil)
    let failed = ChatDecisions.Posted(posted: false, thread: "chat-1", error: "disk full")
    XCTAssertTrue(ChatDecisions.givesWayToMessage(.answer(option), chat: posted, inThread: true))
    XCTAssertTrue(ChatDecisions.givesWayToMessage(.close(reason: "x"), chat: posted, inThread: true))
    XCTAssertTrue(ChatDecisions.givesWayToMessage(.abandon(reason: nil), chat: posted, inThread: true))
    XCTAssertFalse(ChatDecisions.givesWayToMessage(.answer(option), chat: posted, inThread: false), "on Decisions")
    XCTAssertFalse(ChatDecisions.givesWayToMessage(.answer(option), chat: failed, inThread: true))
    XCTAssertFalse(ChatDecisions.givesWayToMessage(.answer(option), chat: nil, inThread: true), "an older Cockpit")
    XCTAssertFalse(ChatDecisions.givesWayToMessage(.snooze(.later), chat: posted, inThread: true))
  }

  func testTheLogSaysWhetherTheChatGotItAndWhyNot() throws {
    let option = try fixture()[0].options[0]
    let posted = ChatDecisions.Posted(posted: true, thread: "chat-1", error: nil)
    let failed = ChatDecisions.Posted(posted: false, thread: nil, error: "the ask has no chat thread")
    XCTAssertEqual(ChatDecisions.chatLogFields(.answer(option), chat: posted) as NSDictionary, ["chat_posted": true])
    XCTAssertEqual(
      ChatDecisions.chatLogFields(.close(reason: "x"), chat: failed) as NSDictionary,
      ["chat_posted": false, "chat_error": "the ask has no chat thread"])
    XCTAssertEqual(
      ChatDecisions.chatLogFields(.answer(option), chat: nil) as NSDictionary,
      ["chat_posted": false, "chat_error": "no chat field"])
    XCTAssertEqual(ChatDecisions.chatLogFields(.snooze(.later), chat: nil) as NSDictionary, [:])
  }

  func testA409AlreadyClosedIsAnsweredElsewhere() {
    XCTAssertEqual(
      outcome(409, #"{"ok": false, "error": "already closed", "ask": {"id": "b", "status": "closed"}}"#),
      .alreadyAnswered)
    XCTAssertEqual(outcome(409, #"{"ok": false, "error": "already closed", "id": "b"}"#), .alreadyAnswered)
  }

  func testA409ChangedCarriesTheAskAsItNowIs() throws {
    let changed = outcome(
      409,
      #"{"ok": false, "error": "changed since you loaded it (server at 2026-11-14T01:00:00Z)", "ask": {"id": "b", "title": "New words", "status": "open", "updated_at": "2026-11-14T01:00:00Z", "options": [{"key": "a", "label": "A"}]}}"#
    )
    guard case .changed(let fresh) = changed else { return XCTFail("\(changed)") }
    XCTAssertEqual(fresh?.title, "New words")
    XCTAssertEqual(fresh?.updatedAt, "2026-11-14T01:00:00Z")
    // /close sends no ask with its 409: read the asks again.
    XCTAssertEqual(
      outcome(409, #"{"ok": false, "error": "changed since you loaded it (server at x)", "id": "b"}"#), .changed(nil))
  }

  func testAnyOtherAnswerIsARefusalInTheCockpitsWords() {
    XCTAssertEqual(
      outcome(502, #"{"ok": false, "error": "bd: database is locked"}"#), .refused("bd: database is locked (HTTP 502)"))
    XCTAssertEqual(outcome(404, #"{"ok": false, "error": "no such bead"}"#), .refused("no such bead (HTTP 404)"))
    XCTAssertEqual(outcome(500, ""), .refused("the Cockpit refused it (HTTP 500)"))
    XCTAssertEqual(outcome(nil), .refused("no answer from the Cockpit"))
    XCTAssertEqual(
      ChatDecisions.outcome(status: nil, body: nil, error: "The request timed out."), .refused("The request timed out.")
    )
  }

  func testRunSendsTheVerbAndReadsItsAnswer() async throws {
    let ask = try fixture()[0]
    var sent: URLRequest?
    let result = await ChatDecisions.run(.answer(ask.options[0]), ask: ask, cockpit: cockpit) { request in
      sent = request
      return (Data(#"{"ok": true}"#.utf8), 200)
    }
    XCTAssertEqual(result, .done(snoozedUntil: nil))
    XCTAssertEqual(sent?.url?.path, "/act")
    let failed = await ChatDecisions.run(.snooze(.later), ask: ask, cockpit: cockpit) { _ in
      throw URLError(.notConnectedToInternet)
    }
    guard case .refused = failed else { return XCTFail("\(failed)") }
  }

  // MARK: The card's lines

  func testTheExpiryReadsInWholeUnits() throws {
    let at = try XCTUnwrap(ChatWire.date("2026-11-15T02:00:00Z"))
    func line(_ seconds: TimeInterval) -> ChatDecisions.Expiry? {
      ChatDecisions.expiry(at, now: at.addingTimeInterval(-seconds))
    }
    XCTAssertEqual(line(5 * 3600 + 59 * 60), .init(text: "Expires in 5 h", expired: false))
    XCTAssertEqual(line(25 * 60), .init(text: "Expires in 25 min", expired: false))
    XCTAssertEqual(line(20), .init(text: "Expires in under a minute", expired: false))
    XCTAssertEqual(line(3 * 86400 + 3600), .init(text: "Expires in 3 d", expired: false))
    XCTAssertEqual(line(-2 * 86400 - 60), .init(text: "Expired 2 d ago", expired: true))
    XCTAssertEqual(line(-90 * 60), .init(text: "Expired 1 h ago", expired: true))
    XCTAssertEqual(line(0), .init(text: "Expired just now", expired: true))
    XCTAssertNil(ChatDecisions.expiry(nil, now: at))
  }

  func testWhatTheCardGivesWayTo() throws {
    let option = try fixture()[0].options[0]
    let pacific = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    XCTAssertEqual(ChatDecisions.doneLine(.answer(option), snoozedUntil: nil), "You decided: The lake loop")
    XCTAssertEqual(ChatDecisions.doneLine(.close(reason: "x"), snoozedUntil: nil), "Closed")
    XCTAssertEqual(ChatDecisions.doneLine(.abandon(reason: nil), snoozedUntil: nil), "Abandoned")
    XCTAssertEqual(
      ChatDecisions.doneLine(.snooze(.nextWeek), snoozedUntil: "2026-11-16T16:00:00Z", timeZone: pacific),
      "Snoozed until Mon 8:00 AM")
    XCTAssertEqual(ChatDecisions.doneLine(.snooze(.later), snoozedUntil: nil), "Snoozed")
    XCTAssertEqual(ChatDecisions.alreadyAnswered, "Already answered elsewhere")
    XCTAssertEqual(ChatDecisions.changed, "This decision changed since it loaded — look again")
  }

  func testTheProblemSaysWhatWasTried() throws {
    let option = try fixture()[0].options[0]
    XCTAssertEqual(
      ChatDecisions.problem(.answer(option), "bd: locked (HTTP 502)"),
      "Could not answer this decision: bd: locked (HTTP 502)")
    XCTAssertEqual(ChatDecisions.problem(.snooze(.later), "x"), "Could not snooze this decision: x")
    XCTAssertEqual(ChatDecisions.problem(.close(reason: "r"), "x"), "Could not close this decision: x")
    XCTAssertEqual(ChatDecisions.problem(.abandon(reason: nil), "x"), "Could not abandon this decision: x")
  }

  // MARK: The session log

  func testTheLogNamesTheVerbAndOutcomeNeverTheWords() throws {
    let option = try fixture()[0].options[1]
    XCTAssertEqual(ChatDecisions.Verb.answer(option).logFields as NSDictionary, ["option": "hill"])
    XCTAssertEqual(
      ChatDecisions.Verb.snooze(.tomorrow).logFields as NSDictionary, ["action": "snooze", "preset": "tomorrow"])
    XCTAssertEqual(
      ChatDecisions.Verb.close(reason: "Booked it").logFields as NSDictionary, ["action": "close", "reason_chars": 9])
    XCTAssertEqual(
      ChatDecisions.Verb.abandon(reason: "Stale").logFields as NSDictionary, ["action": "abandon", "reason_chars": 5])
    XCTAssertEqual(ChatDecisions.Outcome.done(snoozedUntil: nil).logName, "ok")
    XCTAssertEqual(ChatDecisions.Outcome.changed(nil).logName, "changed")
    XCTAssertEqual(ChatDecisions.Outcome.alreadyAnswered.logName, "already_answered")
    XCTAssertEqual(ChatDecisions.Outcome.refused("x").logName, "refused")
  }

  // MARK: Other (story 1128, bead context-grabber-sm4l)

  private func ask(_ labels: [String]) throws -> ChatAsk {
    let options = labels.enumerated().map { ["key": "k\($0.offset)", "label": $0.element] }
    let json: [String: Any] = ["id": "igor2-88g.1620", "title": "Which?", "options": options, "updated_at": "t1"]
    return try JSONDecoder().decode(ChatAsk.self, from: JSONSerialization.data(withJSONObject: json))
  }

  func testAnOptionLabelledOtherIsLarrysOther() {
    for label in ["Other", "other", " OTHER ", "Other…", "Other...", "Other:"] {
      XCTAssertTrue(ChatDecisions.isOther(.init(key: "x", label: label)), label)
    }
    for label in ["Another", "Other team", "Others", "Something other", ""] {
      XCTAssertFalse(ChatDecisions.isOther(.init(key: "x", label: label)), label)
    }
  }

  func testTheCardAddsOtherUnlessLarrysOptionsHaveOne() throws {
    XCTAssertTrue(ChatDecisions.addsOther(try ask(["Tacos", "Ramen"])))
    XCTAssertTrue(ChatDecisions.addsOther(try ask([])), "a card with no options still has Other")
    XCTAssertFalse(ChatDecisions.addsOther(try ask(["Tacos", "Other…"])), "no second Other")
    XCTAssertEqual(ChatDecisions.otherLogName(try ask(["Tacos"]), offered: true), "added")
    XCTAssertEqual(ChatDecisions.otherLogName(try ask(["Tacos", "other"]), offered: true), "ask")
    XCTAssertEqual(ChatDecisions.otherLogName(try ask(["Tacos"]), offered: false), "none")
  }

  /// Larry's *Other* opens the field: the Cockpit never gets the bare word, only Igor's words.
  func testLarrysOtherNeverSendsTheLabelAlone() throws {
    let ask = try ask(["Finger draw", "Other"])
    XCTAssertEqual(ChatDecisions.tap(ask.options[0]), .answer(.answer(ask.options[0])))
    XCTAssertEqual(ChatDecisions.tap(ask.options[1]), .openOther, "a tap on Other answers nothing")
    let request = try ChatDecisions.request(.ownWords("  I don't get finger draw \n"), ask: ask, cockpit: cockpit)
    let sent = try body(request)
    XCTAssertEqual(request.url?.path, "/act")
    XCTAssertEqual(sent["response"] as? String, "DECISION: I don't get finger draw")
    XCTAssertEqual(sent["action"] as? String, "respond")
    XCTAssertEqual(sent["post_to_chat"] as? Bool, true)
    XCTAssertEqual(sent["base_updated_at"] as? String, "t1")
    XCTAssertFalse(ChatDecisions.canSend(words: " \n"), "Send stays off with no words")
    XCTAssertEqual(
      ChatDecisions.doneLine(.ownWords(" I don't get finger draw "), snoozedUntil: nil),
      "You decided: I don't get finger draw")
  }
}
