import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class WhiteboardMarksTests: XCTestCase {
  private let frame = CGRect(x: 1000, y: 2000, width: 300, height: 200)
  private func row(_ id: String, text: String = "", marks: Bool = true) -> WhiteboardMarks.Row {
    WhiteboardMarks.Row(
      id: id, text: text, shapes: marks ? [.init(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])] : [],
      frame: frame, scale: 2)
  }

  func testAPictureAsTheFirstMessageOfABoardsThread() throws {
    var item = InboxItem(
      id: "m1", kind: .image, sharedAt: 1, note: "Your turn on the board",
      whiteboard: WhiteboardPicture(board: "b1", title: "Plan", rect: frame, scale: 2, pictureID: "p1"))
    let first = try ChatSend.messageRequest(item, attachment: "r", cockpit: "https://c.example")
    XCTAssertEqual(first.url?.absoluteString, "https://c.example/chat")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(first.httpBody)) as? [String: Any])
    XCTAssertEqual(body["title"] as? String, "Plan")
    XCTAssertEqual(body["text"] as? String, "Your turn on the board")
    XCTAssertEqual(body["attachments"] as? [String], ["r"])
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["picture_id"] as? String, "p1")
    XCTAssertEqual(
      body["frame"] as? [String: Double], ["x": 1000, "y": 2000, "w": 300, "h": 200, "scale": 2])

    item.thread = "t9"
    let next = try ChatSend.messageRequest(item, attachment: "r", cockpit: "https://c.example")
    XCTAssertEqual(next.url?.absoluteString, "https://c.example/chat/t9")
    let nextBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(next.httpBody)) as? [String: Any])
    XCTAssertNil(nextBody["title"])
    XCTAssertEqual(nextBody["picture_id"] as? String, "p1")
  }

  /// An item waits on disk in the outbox, so its board fields have to survive being read back.
  func testAPictureSurvivesTheOutbox() throws {
    let item = InboxItem(
      kind: .image, sharedAt: 1, whiteboard: WhiteboardPicture(board: "b", title: "T", rect: frame, scale: 2))
    let back = try JSONDecoder().decode(InboxItem.self, from: JSONEncoder().encode(item))
    XCTAssertEqual(back.whiteboard, item.whiteboard)
    XCTAssertNil(
      try JSONDecoder().decode(InboxItem.self, from: JSONEncoder().encode(InboxItem(kind: .text, sharedAt: 1)))
        .whiteboard)
  }

  func testRowsReadLarrysInEitherFormatAndSkipIgors() throws {
    let data = Data(
      #"""
      {"ok": true, "messages": [
        {"id": "i1", "who": "igor", "text": "look", "picture_id": "p1", "frame": {"x": 1, "y": 2, "w": 3, "h": 4, "scale": 2}},
        {"id": "l1", "who": "larry", "text": "  hm  ", "picture_id": "p1",
         "frame": {"x": 1000, "y": 2000, "w": 300, "h": 200, "scale": 2},
         "shapes": [{"kind": "arrow", "points": [[0, 0], [10, 0]]},
                    {"kind": "arrow", "x1": 0, "y1": 0, "x2": 5, "y2": 5},
                    {"kind": "circle", "cx": 10, "cy": 10, "r": 5},
                    {"kind": "star"}, "nonsense"]},
        {"id": "l2", "who": "larry", "text": "words only"}
      ]}
      """#.utf8)
    let rows = try XCTUnwrap(WhiteboardMarks.rows(data))
    XCTAssertEqual(rows.map(\.id), ["l1", "l2"])
    XCTAssertEqual(rows[0].text, "hm")
    XCTAssertEqual(rows[0].pictureID, "p1")
    XCTAssertEqual(rows[0].shapes.map(\.kind), [.arrow, .arrow, .ellipse])
    XCTAssertEqual(rows[0].frame?.origin, CGPoint(x: 1000, y: 2000))
    XCTAssertEqual(rows[0].scale, 2)
    XCTAssertTrue(rows[0].drawable)
    XCTAssertFalse(rows[1].drawable)
    XCTAssertNil(WhiteboardMarks.rows(Data("<html>".utf8)))
    XCTAssertNil(WhiteboardMarks.rows(Data(#"{"ok": false}"#.utf8)))
  }

  /// The row's own frame decides, not where the board is now: pixel (100, 50) at scale 2 is (50, 25) in from it.
  func testMarksLandWhereTheRowsPictureWas() throws {
    let data = Data(
      #"""
      {"ok": true, "messages": [{"id": "l1", "who": "larry", "frame": {"x": 1000, "y": 2000, "w": 300, "h": 200, "scale": 2},
       "shapes": [{"kind": "line", "points": [[100, 50], [200, 50]]}]}]}
      """#.utf8)
    let row = try XCTUnwrap(WhiteboardMarks.rows(data)?.first)
    let lines = WhiteboardTurn.lines(row.shapes[0], frame: try XCTUnwrap(row.frame), scale: row.scale)
    XCTAssertEqual(lines, [[CGPoint(x: 1050, y: 2025), CGPoint(x: 1100, y: 2025)]])
  }

  func testAFrameThatCantBeRightPlacesNothing() {
    XCTAssertNil(WhiteboardMarks.frame(["x": 1, "y": 2, "w": 3]))
    XCTAssertNil(WhiteboardMarks.frame(["x": 1, "y": 2, "w": 3, "h": -4]))
    XCTAssertNil(WhiteboardMarks.frame(["x": 1e300, "y": 2, "w": 3, "h": 4]))
    XCTAssertNil(WhiteboardMarks.frame(["x": 1, "y": 2, "w": 3, "h": 4, "scale": 0]))
    XCTAssertNil(WhiteboardMarks.frame(["x": 1, "y": 2, "w": 3, "h": 4, "scale": "big"]))
    XCTAssertEqual(WhiteboardMarks.frame(["x": 1, "y": 2, "w": 3, "h": 4])?.scale, 1)
  }

  func testOpeningShowsOnlyTheNewestRowOfMarks() {
    var marks = WhiteboardMarks()
    let update = marks.take(
      [row("a", text: "old"), row("b", text: "newest"), row("c", text: "words", marks: false)], settled: [])
    XCTAssertEqual(update.marks.map(\.id), ["b"])
    XCTAssertEqual(update.say, "newest")
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: []), .init())
  }

  func testOpeningOnASettledRowShowsNothingAndNeverAnOlderOne() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([row("a", text: "old"), row("b", text: "new")], settled: ["b"]), .init())
    XCTAssertEqual(marks.take([row("a"), row("b")], settled: ["b"]), .init())
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: ["b"]).marks.map(\.id), ["c"])
  }

  /// Story 808: a kept or dismissed mark is remembered alone, so the rest of its row still comes back on opening; a row
  /// no longer showing has its forgotten.
  func testSettlingRemembersOnlyTheKeptOrDismissedMarksOfRowsStillShowing() {
    let (a0, a2) = (WhiteboardMarks.mark(0, of: "a"), WhiteboardMarks.mark(2, of: "a"))
    XCTAssertNotEqual(a0, WhiteboardMarks.mark(0, of: "b"))
    XCTAssertNotEqual(WhiteboardMarks.mark(1, of: "a"), WhiteboardMarks.mark(0, of: "a1"))
    var settled = WhiteboardMarks.settling(a0, after: [], showing: ["a"])
    XCTAssertEqual(settled, [a0])
    settled = WhiteboardMarks.settling(a2, after: settled, showing: ["a"])
    XCTAssertEqual(settled, [a0, a2])
    XCTAssertEqual(WhiteboardMarks.settling(a2, after: settled, showing: ["a"]), [a0, a2])
    let b1 = WhiteboardMarks.mark(1, of: "b")
    XCTAssertEqual(WhiteboardMarks.settling(b1, after: settled, showing: ["a", "b"]), [a0, a2, b1], "a still shows")
    XCTAssertEqual(WhiteboardMarks.settling(b1, after: settled, showing: ["b"]), [b1], "a shows no more")
  }

  // MARK: Story 1155 (bead context-grabber-n8ab): a new reply adds his marks, never clears them

  /// Board 8f986938, 2026-11-22: his twelve-mark diagram showing, then a label with a question card. Both show, and on
  /// opening again so do both, less what was kept or dismissed.
  func testANewReplyAddsAndBothComeBackOnOpening() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([row("diagram")], settled: []).marks.map(\.id), ["diagram"])
    var showing = WhiteboardMarks.showing("diagram", after: [])
    let update = marks.take([row("diagram"), row("label", text: "which one?")], settled: [])
    XCTAssertEqual(update.marks.map(\.id), ["label"], "the new row's marks, to join the diagram's")
    showing = WhiteboardMarks.showing("label", after: showing)
    XCTAssertEqual(showing, ["diagram", "label"])

    var opened = WhiteboardMarks()
    let rows = [row("older"), row("diagram"), row("label", text: "which one?"), row("words", text: "hm", marks: false)]
    let again = opened.take(rows, settled: [], showing: showing)
    XCTAssertEqual(again.marks.map(\.id), ["diagram", "label"], "a row this device never showed stays in Chat")
    XCTAssertEqual(again.say, "which one?")
    var later = WhiteboardMarks()
    XCTAssertEqual(
      later.take(rows, settled: ["label"], showing: ["diagram"]).marks.map(\.id), ["diagram"],
      "the newest done with, the earlier one still to deal with")
    var none = WhiteboardMarks()
    XCTAssertEqual(none.take(rows, settled: ["label"], showing: []), .init(), "done with, and nothing else showing")
  }

  func testSeveralRowsLandingBetweenTwoLooksAllShow() {
    var marks = WhiteboardMarks()
    _ = marks.take([row("a")], settled: [])
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: []).marks.map(\.id), ["b", "c"])
  }

  func testShowingRemembersTheNewestRowsUpToItsLimit() {
    var showing: [String] = []
    for i in 0..<(WhiteboardMarks.rowsKept + 5) { showing = WhiteboardMarks.showing("r\(i)", after: showing) }
    XCTAssertEqual(showing.count, WhiteboardMarks.rowsKept)
    XCTAssertEqual(showing.last, "r\(WhiteboardMarks.rowsKept + 4)")
    XCTAssertEqual(WhiteboardMarks.showing("r10", after: showing).last, "r10", "shown again: the newest")
    XCTAssertEqual(WhiteboardMarks.showing("r10", after: showing).count, WhiteboardMarks.rowsKept)
  }

  /// Keeping or dismissing the last mark of a row is done with it: it shows no more, its remembered marks go, and it is
  /// remembered as done, so it doesn't come back as the newest row. Another row's marks left keep it showing.
  func testSettlingTheLastMarkOfARowIsDoneWithItAlone() {
    let (a0, a1, b0) = (
      WhiteboardMarks.mark(0, of: "a"), WhiteboardMarks.mark(1, of: "a"), WhiteboardMarks.mark(0, of: "b")
    )
    var state = WhiteboardMarks.settle(a0, left: [a1, b0], showing: ["a", "b"], settled: [], done: [])
    XCTAssertEqual(state.showing, ["a", "b"])
    XCTAssertEqual(state.settled, [a0])
    XCTAssertEqual(state.done, [])
    state = WhiteboardMarks.settle(b0, left: [a1], showing: state.showing, settled: state.settled, done: state.done)
    XCTAssertEqual(state.showing, ["a"], "b is done with; a still shows")
    XCTAssertEqual(state.settled, [a0])
    XCTAssertEqual(state.done, ["b"])
    state = WhiteboardMarks.settle(a1, left: [], showing: state.showing, settled: state.settled, done: state.done)
    XCTAssertEqual(state.showing, [])
    XCTAssertEqual(state.settled, [])
    XCTAssertEqual(state.done, ["b", "a"])
    let text = WhiteboardMarks.settle("fake-text-1", left: [], showing: ["a"], settled: [a0], done: [])
    XCTAssertEqual(text.showing, ["a"], "his text from a change is no row's mark")
    XCTAssertEqual(text.settled, [a0])
  }

  func testEachNewRowShowsAndASeenOneNeverComesBack() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([], settled: []), .init())
    let first = marks.take([row("a", text: "here")], settled: [])
    XCTAssertEqual(first.marks.map(\.id), ["a"])
    XCTAssertEqual(first.say, "here")
    // Dismissed between looks: nothing settled needed, it has been seen.
    XCTAssertEqual(marks.take([row("a", text: "here")], settled: []), .init())
    let words = marks.take([row("a"), row("w", text: "just words", marks: false)], settled: [])
    XCTAssertEqual(words.marks, [])
    XCTAssertEqual(words.say, "just words")
    let both = marks.take(
      [row("a"), row("w", marks: false), row("b"), row("c")], settled: [])
    XCTAssertEqual(both.marks.map(\.id), ["b", "c"], "every new row of marks shows (story 1155)")
    XCTAssertNil(both.say)
  }

  func testARowWithNowhereToPutItsMarksIsNamedAndReplacesNothing() {
    var marks = WhiteboardMarks()
    _ = marks.take([row("a")], settled: [])
    let lost = WhiteboardMarks.Row(
      id: "b", text: "see", shapes: [.init(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])])
    let update = marks.take([row("a"), lost], settled: [])
    XCTAssertEqual(update.marks, [])
    XCTAssertEqual(update.unplaced, ["b"])
    XCTAssertEqual(update.say, "see")
  }

  /// Story 387: the newest row has nowhere to go, so an older row doesn't stand in for it, and the log can name it.
  func testOpeningOnANewestRowWithNoPlaceShowsNothingAndNamesIt() {
    var marks = WhiteboardMarks()
    let lost = WhiteboardMarks.Row(
      id: "b", text: "see", shapes: [.init(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])])
    let update = marks.take([row("a", text: "old"), lost, row("c", text: "words", marks: false)], settled: [])
    XCTAssertEqual(update.marks, [])
    XCTAssertNil(update.say)
    XCTAssertEqual(update.unplaced, ["b"])
    XCTAssertEqual(marks.take([row("a"), lost], settled: []), .init())
  }

  // MARK: The board's one thread (story 385)

  private func makeThreads() throws -> WhiteboardThreads {
    let suite = "whiteboard-threads-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
    return WhiteboardThreads(defaults: defaults)
  }

  private func outbox() throws -> InboxStore {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return InboxStore(directory: directory)
  }

  private func picture(_ id: String, at: Int64, board: String = "b1", thread: String? = nil) -> InboxItem {
    InboxItem(
      id: id, kind: .text, sharedAt: at, text: "board", thread: thread,
      whiteboard: WhiteboardPicture(board: board, title: "Plan", rect: frame, scale: 2))
  }

  private actor Paths {
    var all: [String] = []
    func add(_ path: String) { all.append(path) }
  }

  /// Two Sends queued with no thread go to one thread, and the board keeps it with nobody watching: the sent items can
  /// be forgotten by Chat, and another board's thread is left alone.
  func testPicturesQueuedWithNoThreadShareTheOneTheFirstStarts() async throws {
    let store = try outbox()
    let threads = try makeThreads()
    threads.set("other", board: "b2")
    try store.add(picture("m1", at: 1))
    try store.add(picture("m2", at: 2))
    XCTAssertTrue(threads.firstSendWaiting(board: "b1", in: store.items().items))
    let paths = Paths()
    let sender = InboxSender(store: store, cockpit: "https://c.example", threads: threads) { request in
      await paths.add(request.url?.path ?? "")
      return (
        Data(#"{"ok": true, "thread": "t9"}"#.utf8),
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
      )
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["m1", "m2"])
    let sentTo = await paths.all
    XCTAssertEqual(sentTo, ["/chat", "/chat/t9"])
    XCTAssertEqual(threads.thread(board: "b1"), "t9")
    XCTAssertEqual(threads.thread(board: "b2"), "other")
    XCTAssertEqual(store.item("m2")?.chatThread, "t9")
    XCTAssertFalse(threads.firstSendWaiting(board: "b1", in: store.items().items))
    XCTAssertEqual(report.boardThreads, ["b1"], "it started once, so the boards sync once (context-grabber-e3vb)")
  }

  /// The Cockpit no longer has the thread: that picture is refused and the board's next one starts a new thread.
  func testAPictureToAThreadTheCockpitLostFreesTheBoard() async throws {
    let store = try outbox()
    let threads = try makeThreads()
    threads.set("gone", board: "b1")
    try store.add(picture("m1", at: 1))
    let sender = InboxSender(store: store, cockpit: "https://c.example", threads: threads) { request in
      (
        Data(#"{"ok": false, "error": "no such thread"}"#.utf8),
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)!
      )
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.refused, ["m1"])
    XCTAssertNil(threads.thread(board: "b1"))
    // context-grabber-e3vb: remembered as gone, so the board's iCloud copy stops carrying it, on a sync now.
    XCTAssertEqual(threads.gone(), ["b1": "gone"])
    XCTAssertEqual(report.boardThreads, ["b1"])
  }

  /// A failed send keeps its place in the outbox, so a turn stays held back; a share isn't a board's picture.
  func testOnlyABoardsOwnWaitingPictureHoldsBackItsTurn() throws {
    let threads = try makeThreads()
    XCTAssertFalse(threads.firstSendWaiting(board: "b1", in: []))
    XCTAssertFalse(
      threads.firstSendWaiting(board: "b1", in: [InboxItem(id: "s", kind: .text, sharedAt: 1, text: "share")]))
    XCTAssertFalse(threads.firstSendWaiting(board: "b1", in: [picture("m", at: 1, board: "b2")]))
    XCTAssertTrue(threads.firstSendWaiting(board: "b1", in: [picture("m", at: 1)]))
    threads.set("t", board: "b1")
    XCTAssertFalse(threads.firstSendWaiting(board: "b1", in: [picture("m", at: 1)]))
  }

  func testForgettingAnOldThreadLeavesANewerOne() throws {
    let threads = try makeThreads()
    threads.set("new", board: "b1")
    XCTAssertFalse(threads.forget("old", board: "b1"))
    XCTAssertEqual(threads.thread(board: "b1"), "new")
    XCTAssertEqual(threads.gone(), [:], "nothing forgotten, nothing to clear from iCloud")
  }

  /// context-grabber-e3vb: a forgotten thread is remembered as gone until the board's next thread starts.
  func testAForgottenThreadIsGoneUntilANewOneStarts() throws {
    let threads = try makeThreads()
    threads.set("t1", board: "b1")
    XCTAssertTrue(threads.forget("t1", board: "b1"))
    XCTAssertEqual(threads.gone(), ["b1": "t1"])
    XCTAssertEqual(threads.all(), [:], "a gone thread is never read as the board's")
    threads.set("t2", board: "b1")
    XCTAssertEqual(threads.gone(), [:])
    XCTAssertEqual(threads.all(), ["b1": "t2"])
  }

  /// The board's turn opened the thread and his answer was on it before the first look: it is still his answer, said
  /// and replied, with its marks (the stale-push UI test, 2026-11-17: the fake answer beat the first look).
  func testAnAnswerOnANewThreadBeforeTheFirstLookIsStillAnAnswer() {
    var marks = WhiteboardMarks()
    marks.threadStarted()
    let update = marks.take([row("a", text: "made room", marks: false)], settled: [])
    XCTAssertTrue(update.replied)
    XCTAssertEqual(update.say, "made room")
  }

  func testWithoutThreadStartedTheFirstLookStillTakesNothingAsAReply() {
    var marks = WhiteboardMarks()
    let update = marks.take([row("a", text: "made room", marks: false)], settled: [])
    XCTAssertFalse(update.replied, "rows already on a thread the board opened earlier aren't answers")
  }
}
