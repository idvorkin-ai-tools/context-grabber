import CoreGraphics
import Foundation
import XCTest

@testable import ContextCore

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
      [row("a", text: "old"), row("b", text: "newest"), row("c", text: "words", marks: false)], settled: nil)
    XCTAssertEqual(update.marks?.id, "b")
    XCTAssertEqual(update.say, "newest")
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: nil), .init())
  }

  func testOpeningOnASettledRowShowsNothingAndNeverAnOlderOne() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([row("a", text: "old"), row("b", text: "new")], settled: "b"), .init())
    XCTAssertEqual(marks.take([row("a"), row("b")], settled: "b"), .init())
    XCTAssertEqual(marks.take([row("a"), row("b"), row("c")], settled: "b").marks?.id, "c")
  }

  func testEachNewRowShowsAndASeenOneNeverComesBack() {
    var marks = WhiteboardMarks()
    XCTAssertEqual(marks.take([], settled: nil), .init())
    let first = marks.take([row("a", text: "here")], settled: nil)
    XCTAssertEqual(first.marks?.id, "a")
    XCTAssertEqual(first.say, "here")
    // Dismissed between looks: nothing settled needed, it has been seen.
    XCTAssertEqual(marks.take([row("a", text: "here")], settled: nil), .init())
    let words = marks.take([row("a"), row("w", text: "just words", marks: false)], settled: nil)
    XCTAssertNil(words.marks)
    XCTAssertEqual(words.say, "just words")
    let both = marks.take(
      [row("a"), row("w", marks: false), row("b"), row("c")], settled: nil)
    XCTAssertEqual(both.marks?.id, "c")
    XCTAssertNil(both.say)
  }

  func testARowWithNowhereToPutItsMarksIsNamedAndReplacesNothing() {
    var marks = WhiteboardMarks()
    _ = marks.take([row("a")], settled: nil)
    let lost = WhiteboardMarks.Row(
      id: "b", text: "see", shapes: [.init(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])])
    let update = marks.take([row("a"), lost], settled: nil)
    XCTAssertNil(update.marks)
    XCTAssertEqual(update.unplaced, ["b"])
    XCTAssertEqual(update.say, "see")
  }

  /// Story 387: the newest row has nowhere to go, so an older row doesn't stand in for it, and the log can name it.
  func testOpeningOnANewestRowWithNoPlaceShowsNothingAndNamesIt() {
    var marks = WhiteboardMarks()
    let lost = WhiteboardMarks.Row(
      id: "b", text: "see", shapes: [.init(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])])
    let update = marks.take([row("a", text: "old"), lost, row("c", text: "words", marks: false)], settled: nil)
    XCTAssertNil(update.marks)
    XCTAssertNil(update.say)
    XCTAssertEqual(update.unplaced, ["b"])
    XCTAssertEqual(marks.take([row("a"), lost], settled: nil), .init())
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
    threads.forget("old", board: "b1")
    XCTAssertEqual(threads.thread(board: "b1"), "new")
  }
}
