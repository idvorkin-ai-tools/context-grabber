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
}
