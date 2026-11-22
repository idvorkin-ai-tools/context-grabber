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
    _ = marks.take([row("a")], settled: ["b"])
    XCTAssertEqual(marks.take([row("a"), row("b")], settled: ["b"]).marks, [])
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: ["b"]).marks.map(\.id), ["c"])
  }

  func testSettlingRemembersOnlyTheKeptOrDismissedMarksOfRowsStillShowing() throws {
    var history = WhiteboardMarks.History()
    let a = try XCTUnwrap(row("a").drawing)
    let b = try XCTUnwrap(row("b").drawing)
    history.place(a, shown: ["a#0", "a#1", "a#2"])
    history.place(b, shown: ["b#0", "b#1"])
    history.settle("a#0", left: ["a#1", "a#2"])
    history.settle("a#2", left: ["a#1"])
    history.settle("a#2", left: ["a#1"])
    history.settle("b#1", left: ["b#0"])
    XCTAssertEqual(history.settled, ["a#0", "a#2", "b#1"])
    history.settle("a#1", left: ["b#0"])
    XCTAssertEqual(history.settled, ["b#1"])
  }

  // MARK: Story 1155 (bead context-grabber-n8ab): a new reply adds his marks, never clears them

  /// Board 8f986938, 2026-11-22: his twelve-mark diagram showing, then a label with a question card. Both show, and on
  /// opening again so do both, less what was kept or dismissed.
  func testANewReplyAddsAndBothComeBackOnOpening() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([row("diagram")], settled: []).marks.map(\.id), ["diagram"])
    let update = marks.take([row("diagram"), row("label", text: "which one?")], settled: [])
    XCTAssertEqual(update.marks.map(\.id), ["label"], "the new row's marks, to join the diagram's")

    var opened = WhiteboardMarks()
    let rows = [row("older"), row("diagram"), row("label", text: "which one?"), row("words", text: "hm", marks: false)]
    let again = opened.take(rows, settled: [], showing: ["diagram", "label"])
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

  func testShowingRemembersTheLatestTwentyVisibleReplies() throws {
    var history = WhiteboardMarks.History()
    for index in 0..<25 {
      let id = "r\(index)"
      history.place(try XCTUnwrap(row(id).drawing), shown: ["\(id)#0"])
    }
    let expected = (5..<25).map { "r\($0)" }
    XCTAssertEqual(history.showing.map(\.id), expected)
    history.place(try XCTUnwrap(row("r10").drawing), shown: ["r10#0"])
    XCTAssertEqual(history.showing.map(\.id), expected, "reopening a retained reply preserves its place")
    history.place(try XCTUnwrap(row("unresolved").drawing), shown: [], nowhere: ["unresolved#0"])
    XCTAssertEqual(history.showing.map(\.id), expected, "an invisible row takes no slot")
    XCTAssertEqual(history.done, ["unresolved"])
  }

  func testSettlingTwentyOlderRepliesPreservesTheNewestOnReopen() throws {
    let rows = (0...20).map { row("r\($0)") }
    var history = WhiteboardMarks.History()
    history.newest = "r20"
    for reply in rows { history.place(try XCTUnwrap(reply.drawing), shown: ["\(reply.id)#0"]) }
    history.settle("r20#0", left: [])
    for reply in rows.dropLast() { history.settle("\(reply.id)#0", left: []) }
    XCTAssertEqual(history.done.count, 20)
    XCTAssertEqual(history.showing.map(\.id), [])
    var opened = WhiteboardMarks()
    XCTAssertEqual(opened.take(rows, settled: Set(history.done)).marks, [])
  }

  func testSettlingTheLastMarkOfARowIsDoneWithItAlone() throws {
    var history = WhiteboardMarks.History()
    history.place(try XCTUnwrap(row("a").drawing), shown: ["a#0", "a#1"])
    history.place(try XCTUnwrap(row("b").drawing), shown: ["b#0"])
    history.settle("a#0", left: ["a#1", "b#0"])
    XCTAssertEqual(history.showing.map(\.id), ["a", "b"])
    XCTAssertEqual(history.settled, ["a#0"])
    XCTAssertEqual(history.done, [])
    history.settle("b#0", left: ["a#1"])
    XCTAssertEqual(history.showing.map(\.id), ["a"])
    XCTAssertEqual(history.settled, ["a#0"])
    XCTAssertEqual(history.done, ["b"])
    history.settle("a#1", left: [])
    XCTAssertEqual(history.showing.map(\.id), [])
    XCTAssertEqual(history.settled, [])
    XCTAssertEqual(history.done, ["b", "a"])
  }

  func testReplacedThreadLeavesItsDrawingsAvailableAfterReopen() throws {
    let old = WhiteboardMarks.Row(
      id: "old",
      shapes: [
        .init(kind: .connector, points: [], from: "left", to: "right"),
        .init(kind: .text, points: [CGPoint(x: 20, y: 40)], text: "Look", color: 0xaabbcc, lettering: .font),
      ], pictureID: "picture", frame: frame, scale: 2)
    let replacement = row("replacement")
    var history = WhiteboardMarks.History()
    history.place(try XCTUnwrap(old.drawing), shown: ["old#1"], nowhere: ["old#0"])
    history.place(try XCTUnwrap(replacement.drawing), shown: ["replacement#0"])

    let saved = try PropertyListEncoder().encode(history)
    let reopened = try PropertyListDecoder().decode(WhiteboardMarks.History.self, from: saved)
    let drawing = try XCTUnwrap(reopened.restore(excluding: ["replacement"]).first)
    XCTAssertEqual(drawing.id, "old")
    XCTAssertEqual(drawing.shapes, old.shapes)
    XCTAssertEqual(drawing.frame, CGRect(x: 1000, y: 2000, width: 300, height: 200))
    XCTAssertEqual(drawing.scale, 2)
    XCTAssertEqual(drawing.pictureID, "picture")
    XCTAssertEqual(reopened.settled, ["old#0"])
    XCTAssertEqual(reopened.restore(excluding: []).map(\.id), ["old", "replacement"])
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

  // MARK: A Send from any device goes to the board's one conversation (story 1158, bead context-grabber-da1)

  private func sender(_ store: InboxStore, _ threads: WhiteboardThreads, _ paths: Paths) -> InboxSender {
    InboxSender(store: store, cockpit: "https://c.example", threads: threads) { request in
      await paths.add(request.url?.path ?? "")
      let path = request.url?.path ?? ""
      let thread = path == "/chat" ? "t-new" : String(path.dropFirst("/chat/".count))
      return (
        Data(#"{"ok": true, "thread": "\#(thread)"}"#.utf8),
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
      )
    }
  }

  /// An iPhone that never sent an iPad's board: its Send goes to the thread the board carries, which it keeps after.
  func testASendWithNoThreadOfItsOwnUsesTheOneTheBoardCarries() async throws {
    let store = try outbox()
    let threads = try makeThreads()
    let thread = threads.board("b1", carried: "t-ipad", drawnHere: false)
    XCTAssertEqual(thread, "t-ipad")
    try store.add(picture("m1", at: 1, thread: thread))
    let paths = Paths()
    let report = await sender(store, threads, paths).sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["m1"])
    let sentTo = await paths.all
    XCTAssertEqual(sentTo, ["/chat/t-ipad"], "no second conversation")
    XCTAssertEqual(threads.thread(board: "b1"), "t-ipad")
    XCTAssertEqual(threads.board("b1", carried: "t-ipad", drawnHere: false), "t-ipad")
  }

  /// A board carrying no thread, on a device with none: the Send starts one and the board keeps it.
  func testASendWithNeitherStartsOneAndRecordsIt() async throws {
    let store = try outbox()
    let threads = try makeThreads()
    let thread = threads.board("b1", carried: nil, drawnHere: true)
    XCTAssertNil(thread)
    try store.add(picture("m1", at: 1, thread: thread))
    let paths = Paths()
    let report = await sender(store, threads, paths).sendWaiting { _, _ in }
    let sentTo = await paths.all
    XCTAssertEqual(sentTo, ["/chat"])
    XCTAssertEqual(threads.thread(board: "b1"), "t-new")
    XCTAssertEqual(report.boardThreads, ["b1"], "the drawing device sends it up with the board")
    XCTAssertEqual(threads.board("b1", carried: nil, drawnHere: true), "t-new")
  }

  /// The carried thread wins on a device that didn't draw the board, even over an older one of its own; on the drawing
  /// device its own is the board's, and a reinstall that knows none uses the carried one.
  func testTheBoardsThreadIsTheCarriedOneExceptOnTheDrawingDevice() throws {
    let threads = try makeThreads()
    XCTAssertEqual(threads.board("b1", carried: "t-ipad", drawnHere: true), "t-ipad", "a reinstalled iPad")
    XCTAssertNil(threads.board("b1", carried: nil, drawnHere: false))
    threads.set("t-mine", board: "b1")
    XCTAssertEqual(threads.board("b1", carried: "t-ipad", drawnHere: false), "t-ipad")
    XCTAssertEqual(threads.board("b1", carried: "t-ipad", drawnHere: true), "t-mine")
    XCTAssertEqual(threads.board("b1", carried: nil, drawnHere: false), "t-mine")
  }

  /// A carried thread the Cockpit said is gone is never used again, though the board's copy still carries it.
  func testACarriedThreadTheCockpitLostIsNeverUsed() throws {
    let threads = try makeThreads()
    XCTAssertTrue(threads.forget("t-ipad", board: "b1"), "with none of its own, the carried one it used is gone")
    XCTAssertEqual(threads.gone(), ["b1": "t-ipad"])
    XCTAssertNil(threads.board("b1", carried: "t-ipad", drawnHere: false))
    XCTAssertNil(threads.board("b1", carried: "t-ipad", drawnHere: true))
    threads.set("t-next", board: "b1")
    XCTAssertEqual(threads.board("b1", carried: "t-ipad", drawnHere: true), "t-next")
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
