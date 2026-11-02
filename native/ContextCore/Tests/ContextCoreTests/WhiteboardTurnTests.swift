import CoreGraphics
import Foundation
import XCTest

@testable import ContextCore

final class WhiteboardTurnTests: XCTestCase {
  func testTheRequestCarriesThePictureAndWhoseTurn() throws {
    let request = try WhiteboardTurn.request(
      who: .larry, board: "b1", title: "Plan", picture: Data([1, 2, 3]), thread: "t9",
      cockpit: "https://cockpit.example/")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/turn")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.timeoutInterval, 60)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cockpit.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["who"] as? String, "larry")
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["title"] as? String, "Plan")
    XCTAssertEqual(body["thread"] as? String, "t9")
    XCTAssertEqual(body["picture"] as? String, Data([1, 2, 3]).base64EncodedString())
  }

  func testAGhostTurnGivesUpQuicklyAndSendsNoThreadWhenThereIsNone() throws {
    let request = try WhiteboardTurn.request(
      who: .claude, board: "b1", title: "Plan", picture: Data(), thread: nil, cockpit: "https://c.example")
    XCTAssertEqual(request.timeoutInterval, 3)
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertNil(body["thread"])
  }

  func testShapesComeBackAndBadOnesAreSkipped() {
    let body = Data(
      """
      {"ok": true, "say": "the third circle", "thread": "t1", "shapes": [
        {"kind": "ellipse", "points": [[0, 0], [10, 20]]},
        {"kind": "text", "points": [[5, 5]], "text": "dip", "size": 20},
        {"kind": "star", "points": [[0, 0], [1, 1]]},
        {"kind": "line", "points": [[0, 0]]},
        {"kind": "text", "points": [[5, 5]], "text": "  "},
        {"kind": "arrow", "points": [[0, 0], ["x", 1], [3, 4]]}
      ]}
      """.utf8)
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: body),
      .shapes(
        [
          .init(kind: .ellipse, points: [.zero, CGPoint(x: 10, y: 20)]),
          .init(kind: .text, points: [CGPoint(x: 5, y: 5)], text: "dip", size: 20),
          .init(kind: .arrow, points: [.zero, CGPoint(x: 3, y: 4)]),
        ], say: "the third circle", thread: "t1"))
  }

  func testNothingToAddIsAnAnswer() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: Data(#"{"ok": true}"#.utf8)), .shapes([], say: "", thread: nil))
  }

  func testRefusalsAndAbsences() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 400, body: Data(#"{"ok": false, "error": "no picture"}"#.utf8)),
      .refused(status: 400, reason: "no picture"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 404, body: nil), .refused(status: 404, reason: "HTTP 404"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 502, body: nil), .away(reason: "HTTP 502"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 200, body: Data("<html>".utf8)), .away(reason: "HTTP 200"))
    XCTAssertEqual(WhiteboardTurn.answer(status: nil, body: nil, error: "timed out"), .away(reason: "timed out"))
  }

  func testATurnDrawsAtMostFortyShapes() {
    let one = #"{"kind": "line", "points": [[0, 0], [1, 1]]}"#
    let body = Data(#"{"ok": true, "shapes": [\#(Array(repeating: one, count: 50).joined(separator: ","))]}"#.utf8)
    guard case .shapes(let shapes, _, _) = WhiteboardTurn.answer(status: 200, body: body) else { return XCTFail() }
    XCTAssertEqual(shapes.count, 40)
  }

  /// The picture covers `frame` at `scale` pixels a point: pixel (100, 50) at scale 2 is 50 and 25 points in.
  func testPixelsLandOnTheBoardWhereThePictureShowedThem() {
    let frame = CGRect(x: 1000, y: 2000, width: 400, height: 300)
    let line = WhiteboardTurn.lines(
      .init(kind: .line, points: [.zero, CGPoint(x: 100, y: 50)]), frame: frame, scale: 2)
    XCTAssertEqual(line, [[CGPoint(x: 1000, y: 2000), CGPoint(x: 1050, y: 2025)]])
  }

  func testABoxIsClosedAndAnEllipseGoesRoundItsCorners() {
    let box = WhiteboardTurn.lines(
      .init(kind: .rect, points: [CGPoint(x: 10, y: 10), .zero]), frame: .zero, scale: 1)
    XCTAssertEqual(box.count, 1)
    XCTAssertEqual(box[0].first, box[0].last)
    XCTAssertEqual(box[0].count, 5)
    let ellipse = WhiteboardTurn.lines(
      .init(kind: .ellipse, points: [.zero, CGPoint(x: 20, y: 10)]), frame: .zero, scale: 1)[0]
    for p in ellipse {
      XCTAssertEqual(pow((p.x - 10) / 10, 2) + pow((p.y - 5) / 5, 2), 1, accuracy: 1e-9)
    }
  }

  func testAnArrowHasAHeadAtItsEnd() {
    let arrow = WhiteboardTurn.lines(
      .init(kind: .arrow, points: [.zero, CGPoint(x: 90, y: 0)]), frame: .zero, scale: 1)
    XCTAssertEqual(arrow.count, 2)
    XCTAssertEqual(arrow[1][1], CGPoint(x: 90, y: 0))
    XCTAssertTrue(arrow[1][0].x < 90 && arrow[1][0].y < 0)
    XCTAssertTrue(arrow[1][2].x < 90 && arrow[1][2].y > 0)
  }

  func testALabelIsDrawnAsLettersInsideItsBox() {
    let lines = WhiteboardTurn.lines(
      .init(kind: .text, points: [CGPoint(x: 100, y: 100)], text: "Hi", size: 40), frame: .zero, scale: 1)
    XCTAssertFalse(lines.isEmpty)
    let points = lines.flatMap { $0 }
    XCTAssertGreaterThanOrEqual(points.map(\.y).min() ?? 0, 100 - 1)
    XCTAssertLessThanOrEqual(points.map(\.y).max() ?? 0, 100 + 40 + 1)
    XCTAssertGreaterThanOrEqual(points.map(\.x).min() ?? 0, 100 - 1)
  }

  func testATapNearAGhostsLineHitsIt() {
    let lines = [[CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]]
    XCTAssertTrue(WhiteboardTurn.hit(lines, at: CGPoint(x: 50, y: 8), tolerance: 10))
    XCTAssertFalse(WhiteboardTurn.hit(lines, at: CGPoint(x: 50, y: 12), tolerance: 10))
    XCTAssertFalse(WhiteboardTurn.hit(lines, at: CGPoint(x: 115, y: 0), tolerance: 10))
    XCTAssertTrue(WhiteboardTurn.hit([[CGPoint(x: 5, y: 5)]], at: CGPoint(x: 8, y: 5), tolerance: 10))
  }
}
