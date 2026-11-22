import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// #794, stories 559 and 740–742: the chat a shared link started is recommended when the link is shared again.
final class ShareSameLinkTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }
  private let cockpit = "https://cockpit.test"
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let page = "https://idvork.in/eulogy"

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("same-link-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  private func row(_ key: String, done: Bool = false) -> ChatSummary {
    ChatSummary(key: key, title: key, lastTs: "2026-11-01T10:00:00+00:00", lastWho: "igor", lastText: "", done: done)
  }

  /// A chat `url` started `hours` ago.
  private func start(_ thread: String, _ url: String? = nil, hours: Double) -> ShareSameLink.Start {
    ShareSameLink.Start(
      link: ShareSameLink.key(url ?? page) ?? "", thread: thread,
      startedAt: Int64((now.timeIntervalSince1970 - hours * 3600) * 1000))
  }

  private func recommended(_ url: String?, _ starts: [ShareSameLink.Start], live: [String]) -> String? {
    ShareSameLink.recommended(url: url, starts: starts, live: live.map { row($0) }, now: now)
  }

  // MARK: Story 740: the same page under another address

  func testTheSamePageHasOneKeyHoweverItsAddressIsDressed() {
    let same = [
      "https://idvork.in/eulogy", "http://idvork.in/eulogy", "https://www.idvork.in/eulogy",
      "https://IDVORK.in/eulogy/", "https://idvork.in/eulogy#roles", "https://idvork.in:443/eulogy",
      "https://idvork.in/eulogy?utm_source=share&utm_medium=ios", "https://idvork.in/eulogy?fbclid=abc&igshid=xyz",
      " https://idvork.in/eulogy\n",
    ]
    XCTAssertEqual(Set(same.map { ShareSameLink.key($0) }), ["idvork.in/eulogy"])
  }

  func testTheSiteAloneIsOnePageWithOrWithoutItsSlash() {
    XCTAssertEqual(ShareSameLink.key("https://idvork.in"), "idvork.in")
    XCTAssertEqual(ShareSameLink.key("https://idvork.in/"), "idvork.in")
  }

  func testWhatFollowsTheQuestionMarkCountsInAnyOrderWithoutTheTrackingTags() {
    let key = ShareSameLink.key("https://youtube.com/watch?v=abc&t=10")
    XCTAssertEqual(key, "youtube.com/watch?t=10&v=abc")
    XCTAssertEqual(ShareSameLink.key("https://www.youtube.com/watch?t=10&si=share&v=abc&UTM_Campaign=x"), key)
    XCTAssertEqual(
      ShareSameLink.key("https://youtube.com/watch?v=abc&t=10&si=share&feature=x"),
      "youtube.com/watch?feature=x&t=10&v=abc")
    XCTAssertNotEqual(ShareSameLink.key("https://youtube.com/watch?v=other&t=10"), key)
  }

  func testARouteAfterTheHashIsThePageAndAnyOtherFragmentIsNot() {
    XCTAssertEqual(ShareSameLink.key("https://app.example.com/#/inbox/42"), "app.example.com#/inbox/42")
    XCTAssertNotEqual(
      ShareSameLink.key("https://app.example.com/#/inbox/42"), ShareSameLink.key("https://app.example.com/#/settings"))
    XCTAssertEqual(ShareSameLink.key("https://example.com/a?b=1#!/thread/7"), "example.com/a?b=1#!/thread/7")
    XCTAssertEqual(ShareSameLink.key("https://example.com/a#section"), "example.com/a")
    XCTAssertEqual(ShareSameLink.key("https://example.com/a#:~:text=quoted"), "example.com/a")
    XCTAssertEqual(ShareSameLink.key("https://example.com/a#"), "example.com/a")
  }

  func testSiIsATrackingTagOnYouTubeAndSpotifyOnly() {
    XCTAssertEqual(ShareSameLink.key("https://youtu.be/abc?si=share"), "youtu.be/abc")
    XCTAssertEqual(ShareSameLink.key("https://www.youtube.com/watch?v=abc&si=share"), "youtube.com/watch?v=abc")
    XCTAssertEqual(ShareSameLink.key("https://music.youtube.com/watch?v=abc&SI=share"), "music.youtube.com/watch?v=abc")
    XCTAssertEqual(ShareSameLink.key("https://open.spotify.com/track/1?si=share"), "open.spotify.com/track/1")
    XCTAssertEqual(ShareSameLink.key("https://example.com/item?si=42"), "example.com/item?si=42")
    XCTAssertNotEqual(
      ShareSameLink.key("https://example.com/item?si=42"), ShareSameLink.key("https://example.com/item?si=43"))
  }

  func testAnotherPathOrPortOrSiteIsAnotherPage() {
    let key = ShareSameLink.key(page)
    XCTAssertNotEqual(ShareSameLink.key("https://idvork.in/eulogy/roles"), key)
    XCTAssertNotEqual(ShareSameLink.key("https://idvork.in/Eulogy"), key)
    XCTAssertNotEqual(ShareSameLink.key("https://idvork.in:8443/eulogy"), key)
    XCTAssertNotEqual(ShareSameLink.key("https://blog.idvork.in/eulogy"), key)
  }

  func testOnlyAWebLinkHasAKey() {
    XCTAssertNil(ShareSameLink.key("mailto:igor@example.com"))
    XCTAssertNil(ShareSameLink.key("file:///tmp/a.pdf"))
    XCTAssertNil(ShareSameLink.key("just some words"))
    XCTAssertNil(ShareSameLink.key(""))
  }

  // MARK: Story 559: the chat this link started is recommended

  func testTheChatTheLinkStartedIsRecommendedForTheSamePage() {
    let starts = [start("t-eulogy", hours: 1), start("t-other", "https://example.com/a", hours: 1)]
    let shared = "https://www.idvork.in/eulogy/?utm_source=x#top"
    XCTAssertEqual(recommended(shared, starts, live: ["t-eulogy", "t-other"]), "t-eulogy")
    XCTAssertNil(recommended("https://idvork.in/another", starts, live: ["t-eulogy", "t-other"]))
  }

  func testTheRecommendedChatIsListedFirstAndTakesOneOfTheFivePlaces() {
    let live = ["pinned", "a", "b", "c", "d", "e", "t-eulogy"].map { row($0) }
    XCTAssertEqual(ShareThreads.rows(live, recommended: "t-eulogy").map(\.key), ["t-eulogy", "pinned", "a", "b", "c"])
    XCTAssertEqual(ShareThreads.rows(live, recommended: "b").map(\.key), ["b", "pinned", "a", "c", "d"])
    XCTAssertEqual(ShareThreads.rows(live, recommended: nil).map(\.key), ["pinned", "a", "b", "c", "d"])
    XCTAssertEqual(ShareThreads.rows(live, recommended: "gone").map(\.key), ["pinned", "a", "b", "c", "d"])
  }

  func testTheReadKeepsEveryLiveChatSoOnePastTheFifthCanBeRecommended() async {
    let threads = (1...7).map { #"{"key": "t\#($0)", "title": "T", "last_ts": "2026-11-0\#(9 - $0)T10:00:00+00:00"}"# }
    let body = #"{"ok": true, "threads": [\#(threads.joined(separator: ","))]}"#
    let read = await ShareThreads.read(cockpit: cockpit) { ChatTests.answer($0, 200, body) }
    guard case .threads(let live) = read else { return XCTFail("\(read)") }
    XCTAssertEqual(live.count, 7)
    XCTAssertEqual(ShareThreads.offered(read), "5 chats")
    XCTAssertEqual(ShareThreads.offered(read, recommended: "t7"), "5 chats, same link t7")
  }

  func testTextAndPicturesAndAnUnreadListRecommendNothing() {
    let starts = [start("t-eulogy", hours: 1)]
    XCTAssertNil(recommended(nil, starts, live: ["t-eulogy"]))
    XCTAssertNil(recommended(page, starts, live: []))
    XCTAssertNil(recommended(page, [], live: ["t-eulogy"]))
  }

  // MARK: Story 741: eight hours, and only a live chat

  func testAChatStartedEightHoursAgoIsRecommendedAndOneOlderIsNot() {
    XCTAssertEqual(ShareSameLink.window, 8 * 3600)
    XCTAssertEqual(recommended(page, [start("t", hours: 8)], live: ["t"]), "t")
    XCTAssertNil(recommended(page, [start("t", hours: 8.01)], live: ["t"]))
  }

  func testADoneOrGoneChatIsNotRecommended() {
    let live = ShareThreads.live([row("done", done: true), row("other")])
    let starts = [start("done", hours: 1), start("gone", hours: 2)]
    XCTAssertNil(ShareSameLink.recommended(url: page, starts: starts, live: live, now: now))
  }

  // MARK: Story 742: several chats from the same link

  func testOfSeveralChatsTheLinkStartedTheNewestLiveOneIsRecommended() {
    let starts = [start("older", hours: 5), start("newest-done", hours: 1), start("newer", hours: 2)]
    XCTAssertEqual(recommended(page, starts, live: ["older", "newer"]), "newer")
  }

  // MARK: What the phone remembers

  func testALinkSharedAsANewChatIsRememberedWithTheChatItStartedOnceSent() async throws {
    try store.add(InboxItem(id: "share-1", kind: .link, sharedAt: 1, url: "https://www.idvork.in/eulogy/?utm_source=x"))
    let sender = InboxSender(store: store, cockpit: cockpit) {
      ChatTests.answer($0, 200, #"{"ok": true, "thread": "t-eulogy"}"#)
    }
    let logged = Lines()
    _ = await sender.sendWaiting(now: { [now] in now }, log: { _, fields in logged.add(fields) })
    let at = Int64(now.timeIntervalSince1970 * 1000)
    XCTAssertEqual(
      store.linkStarts(now: now), [ShareSameLink.Start(link: "idvork.in/eulogy", thread: "t-eulogy", startedAt: at)])
    XCTAssertEqual(logged.all.first?["link_start"] as? Bool, true)
    XCTAssertFalse("\(logged.all)".contains("idvork.in"), "the log never holds the address")
    XCTAssertTrue(store.items().unreadable.isEmpty, "the ledger is not read as an item")
    XCTAssertEqual(store.items().items.map(\.id), ["share-1"])
    XCTAssertEqual(recommended(page, store.linkStarts(now: now), live: ["t-eulogy"]), "t-eulogy")
  }

  func testOnlyALinkThatStartedAChatIsRemembered() async throws {
    try store.add(InboxItem(id: "into", kind: .link, sharedAt: 1, url: page, thread: "t-going"))
    try store.add(InboxItem(id: "typed", kind: .text, sharedAt: 2, text: "see \(page)"))
    let sender = InboxSender(store: store, cockpit: cockpit) {
      ChatTests.answer($0, 200, #"{"ok": true, "thread": "t-going"}"#)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent.count, 2)
    XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.path))
  }

  func testALinkStillWaitingHasStartedNothing() async throws {
    try store.add(InboxItem(id: "share-1", kind: .link, sharedAt: 1, url: page))
    let sender = InboxSender(store: store, cockpit: cockpit) { _ in throw URLError(.timedOut) }
    _ = await sender.sendWaiting { _, _ in }
    XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.path))
  }

  func testTheLedgerForgetsWhatIsOlderThanTheWindowAndKeepsOneRowPerLinkAndChat() throws {
    let hour: Int64 = 3_600_000
    XCTAssertTrue(try store.recordLinkStart(url: page, thread: "old", at: hour))
    XCTAssertTrue(try store.recordLinkStart(url: "https://example.com/a", thread: "a", at: 2 * hour))
    XCTAssertTrue(try store.recordLinkStart(url: "https://example.com/a", thread: "a", at: 3 * hour))
    XCTAssertEqual(store.linkStarts(now: at(3)).map(\.thread), ["old", "a"])
    XCTAssertTrue(try store.recordLinkStart(url: page, thread: "new", at: 10 * hour))
    XCTAssertEqual(store.linkStarts(now: at(10)).map(\.thread), ["a", "new"])
    XCTAssertFalse(try store.recordLinkStart(url: "mailto:x@example.com", thread: "m", at: 10 * hour))
  }

  func testAStartPastTheWindowIsNeverReadAndTheAppDropsItFromThePhone() throws {
    let hour: Int64 = 3_600_000
    try store.recordLinkStart(url: page, thread: "old", at: hour)
    try store.recordLinkStart(url: "https://example.com/a", thread: "a", at: 5 * hour)
    XCTAssertEqual(store.linkStarts(now: at(9)).map(\.thread), ["old", "a"])
    XCTAssertEqual(store.linkStarts(now: at(9.5)).map(\.thread), ["a"], "not read, though still on the phone")
    XCTAssertEqual(try store.forgetOldLinkStarts(now: at(9)), 0)
    XCTAssertEqual(try store.forgetOldLinkStarts(now: at(9.5)), 1)
    XCTAssertFalse(try String(contentsOf: ledger, encoding: .utf8).contains("eulogy"))
    XCTAssertEqual(try store.forgetOldLinkStarts(now: at(14)), 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.path), "nothing left, no ledger")
    XCTAssertEqual(try store.forgetOldLinkStarts(now: at(14)), 0)
  }

  func testAMissingOrBrokenLedgerIsNoStarts() throws {
    XCTAssertEqual(store.linkStarts(now: at(0)), [])
    XCTAssertEqual(try store.forgetOldLinkStarts(now: at(0)), 0)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: ledger)
    XCTAssertEqual(store.linkStarts(now: at(0)), [])
    XCTAssertTrue(try store.recordLinkStart(url: page, thread: "t", at: 1))
    XCTAssertEqual(store.linkStarts(now: at(0)).map(\.thread), ["t"])
  }

  private var ledger: URL { dir.appendingPathComponent("link-starts.ledger") }

  /// `hours` after the epoch, the clock the ledger's own tests count from.
  private func at(_ hours: Double) -> Date { Date(timeIntervalSince1970: hours * 3600) }

  private final class Lines: @unchecked Sendable {
    private(set) var all: [[String: Any]] = []
    func add(_ fields: [String: Any]) { all.append(fields) }
  }
}
