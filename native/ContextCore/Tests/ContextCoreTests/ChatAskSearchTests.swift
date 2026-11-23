//  Story 1132 (bead context-grabber-4dme): searching the asks — GET /asks/search as the Cockpit answers it (cockpit
//  story 206, test_ask_search.py's shapes), the request's escaping, the count line, the highlights and a row's tap.

import XCTest

@testable import ContextCore

final class ChatAskSearchTests: XCTestCase {
  private let cockpit = "http://localhost:8798"

  /// The Cockpit's 200: a /threads row plus matches, one hit past the title, one on the title alone (matches []), one
  /// with no matches at all, and an answered one.
  private let found = Data(
    """
    {"ok": true, "fetched_at": "2026-11-22T10:00:00Z", "q": "Grinder  kettlebell", "terms": ["grinder", "kettlebell"],
     "inbox": 4, "open": 2, "answered": 1, "all": true, "count": 4,
     "threads": [
      {"key": "igor2-88g.901", "needs_igor": true, "open": true, "last_ts": "2026-08-30T05:20:00-07:00",
       "root": {"kind": "ask", "id": "igor2-88g.901", "title": "Which coffee grinder?", "priority": 2},
       "items": [], "matches": [
         {"field": "context", "snippet": "… The kettlebell schedule moved to Thursdays."},
         {"field": "option", "snippet": "Baratza Encore — conical burr"},
         {"field": "thread", "snippet": "Larry: the grinder question again"}]},
      {"key": "igor2-88g.903", "needs_igor": true, "open": true,
       "root": {"title": "Grinder for the office?", "snoozed_until": "2026-12-01T00:00:00Z"}, "matches": []},
      {"key": "igor2-88g.905", "needs_igor": true, "root": {"title": ""}},
      {"key": "igor2-88g.902", "needs_igor": false, "open": false,
       "root": {"title": "Renew the passport?"},
       "matches": [{"field": "answer", "snippet": "Go to the downtown agency"}, {"field": "note"}]}
     ]}
    """.utf8)

  func testAFoundSearchDecodesTheRowsTheCountsAndTheMatches() throws {
    guard case .found(let result) = ChatAskSearch.outcome(status: 200, body: found) else {
      return XCTFail("not found")
    }
    XCTAssertEqual(result.terms, ["grinder", "kettlebell"])
    XCTAssertEqual(result.inbox, 4)
    XCTAssertEqual([result.open, result.answered], [2, 1])
    XCTAssertTrue(result.all)
    XCTAssertEqual(result.threads.map(\.key), ["igor2-88g.901", "igor2-88g.903", "igor2-88g.905", "igor2-88g.902"])
    let first = result.threads[0]
    XCTAssertEqual(first.title, "Which coffee grinder?")
    XCTAssertTrue(first.open)
    XCTAssertEqual(first.matches.map(\.field), ["context", "option", "thread"])
    XCTAssertEqual(first.matches.map(\.label), ["context", "option", "in thread"])
    XCTAssertEqual(result.threads[1].matches, [], "a title hit has no lines")
    XCTAssertEqual(result.threads[1].snoozedUntil, "2026-12-01T00:00:00Z")
    XCTAssertEqual(result.threads[2].title, "igor2-88g.905", "an empty title is the key")
    XCTAssertEqual(result.threads[2].matches, [], "no matches field at all")
    XCTAssertFalse(result.threads[3].open)
    XCTAssertEqual(result.threads[3].matches, [ChatAskHit.Match(field: "answer", snippet: "Go to the downtown agency")])
    XCTAssertNil(result.emptyLine)
  }

  func testNoRowsSaysNoAsksMatchAndTheCountSaysWhatTheTickWouldShow() throws {
    let body = Data(
      """
      {"ok": true, "q": "passport", "terms": ["passport"], "inbox": 1, "open": 0, "answered": 3, "all": false,
       "count": 0, "threads": []}
      """.utf8)
    guard case .found(let result) = ChatAskSearch.outcome(status: 200, body: body) else { return XCTFail("not found") }
    XCTAssertEqual(result.emptyLine, "No asks match.")
    XCTAssertEqual(result.countLine, "0 open · 3 answered (tick to show)")
    let shown = ChatAskSearchResult(q: "passport", terms: ["passport"], open: 0, answered: 3, all: true, threads: [])
    XCTAssertEqual(shown.countLine, "0 open · 3 answered", "ticked: no hint")
    let none = ChatAskSearchResult(q: "x", terms: ["x"], open: 2, answered: 0, all: false, threads: [])
    XCTAssertEqual(none.countLine, "2 open · 0 answered", "nothing to tick for")
  }

  func testAnEmptyQueryIsA400AndBdDownIsA502BothCopyable() {
    let empty = Data(#"{"ok": false, "error": "q is required"}"#.utf8)
    XCTAssertEqual(
      ChatAskSearch.outcome(status: 400, body: empty), .failed("q is required (HTTP 400)", status: 400))
    let down = Data(#"{"ok": false, "error": "bd: database is locked"}"#.utf8)
    XCTAssertEqual(
      ChatAskSearch.outcome(status: 502, body: down), .failed("bd: database is locked (HTTP 502)", status: 502))
    XCTAssertEqual(
      ChatAskSearch.outcome(status: 502, body: Data("<html>".utf8)),
      .failed("the Cockpit refused it (HTTP 502)", status: 502))
    XCTAssertEqual(
      ChatAskSearch.outcome(status: nil, body: nil, error: "offline"), .failed("offline", status: nil))
    XCTAssertEqual(
      ChatAskSearch.outcome(status: 200, body: Data(#"{"ok": true, "asks": []}"#.utf8)),
      .failed("an answer that is not a search: unreadable", status: 200))
    XCTAssertEqual(ChatAskSearch.problem("x (HTTP 502)"), "Could not search the asks: x (HTTP 502)")
  }

  func testTheRequestEscapesWhatWouldChangeTheQuery() throws {
    let plain = try XCTUnwrap(ChatAskSearch.request(cockpit: cockpit, q: " kindle  reconnect ", all: false))
    XCTAssertEqual(plain.url?.absoluteString, "http://localhost:8798/asks/search?q=kindle%20%20reconnect")
    XCTAssertEqual(plain.httpMethod, "GET")
    let all = try XCTUnwrap(ChatAskSearch.request(cockpit: cockpit + "/", q: "c++ a&b <x> #1 =", all: true))
    XCTAssertEqual(
      all.url?.absoluteString,
      "http://localhost:8798/asks/search?q=c%2B%2B%20a%26b%20%3Cx%3E%20%231%20%3D&all=1")
    let items = URLComponents(url: try XCTUnwrap(all.url), resolvingAgainstBaseURL: false)?.queryItems
    XCTAssertEqual(items?.first { $0.name == "q" }?.value, "c++ a&b <x> #1 =")
    XCTAssertEqual(items?.first { $0.name == "all" }?.value, "1")
    XCTAssertNil(try ChatAskSearch.request(cockpit: cockpit, q: "  \n ", all: false), "no words, no search")
    XCTAssertThrowsError(try ChatAskSearch.request(cockpit: "nowhere", q: "x", all: false))
  }

  func testTermsSplitOnWhitespaceLowercased() {
    XCTAssertEqual(ChatAskSearch.terms("  Kindle\tRECONNECT  a.b "), ["kindle", "reconnect", "a.b"])
    XCTAssertEqual(ChatAskSearch.terms(" "), [])
  }

  func testPiecesMarkEveryTermCaseIgnoredEarliestThenLongest() {
    typealias P = ChatAskSearch.Piece
    XCTAssertEqual(
      ChatAskSearch.pieces("Reconnect the Kindle Scribe", terms: ["kindle", "reconnect"]),
      [P("Reconnect", hit: true), P(" the ", hit: false), P("Kindle", hit: true), P(" Scribe", hit: false)])
    XCTAssertEqual(
      ChatAskSearch.pieces("grinders", terms: ["grind", "grinder"]),
      [P("grinder", hit: true), P("s", hit: false)], "the longest where two start together")
    XCTAssertEqual(
      ChatAskSearch.pieces("a.b and <x>", terms: ["a.b", "<x>"]),
      [P("a.b", hit: true), P(" and ", hit: false), P("<x>", hit: true)], "characters are just characters")
    XCTAssertEqual(ChatAskSearch.pieces("nothing here", terms: ["zz"]), [P("nothing here", hit: false)])
    XCTAssertEqual(ChatAskSearch.pieces("text", terms: []), [P("text", hit: false)])
    XCTAssertEqual(ChatAskSearch.pieces("aaa", terms: ["a"]).filter(\.hit).count, 3, "every place")
  }

  func testATapOpensTheOpenAsksChatAKnownThreadOrTheCockpitPage() throws {
    let ask = try JSONDecoder().decode(
      ChatAsk.self, from: Data(#"{"id": "igor2-88g.881", "title": "Lunch?", "thread": "igor2-88g.878"}"#.utf8))
    let open = ChatAskHit(key: "igor2-88g.881", title: "Lunch?", open: true)
    XCTAssertEqual(ChatAskSearch.opens(open, asks: [ask], known: []), .thread("igor2-88g.878"), "where its card is")
    let answered = ChatAskHit(key: "igor2-88g.902", title: "Passport?", open: false)
    XCTAssertEqual(ChatAskSearch.opens(answered, asks: [ask], known: ["igor2-88g.902"]), .thread("igor2-88g.902"))
    guard case .web(let page) = ChatAskSearch.opens(answered, asks: [ask], known: []) else {
      return XCTFail("the Cockpit's page")
    }
    XCTAssertEqual(page, ChatCockpitLink.webURL("igor2-88g.902"))
  }

  func testTheLogNeverHoldsTheWords() {
    let fields = ChatAskSearch.logFields(q: "secret plans", all: true)
    XCTAssertEqual(fields["terms"] as? Int, 2)
    XCTAssertEqual(fields["q_chars"] as? Int, 12)
    XCTAssertEqual(fields["all"] as? Bool, true)
    XCTAssertFalse(fields.values.contains { ($0 as? String)?.contains("secret") == true })
  }
}
