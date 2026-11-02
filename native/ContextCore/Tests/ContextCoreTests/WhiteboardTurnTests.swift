import CoreGraphics
import Foundation
import PencilKit
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

  func testATurnSendsNoThreadWhenThereIsNone() throws {
    let request = try WhiteboardTurn.request(
      who: .claude, board: "b1", title: "Plan", picture: Data(), thread: nil, cockpit: "https://c.example")
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

  /// An emoji is a bitmap with no outline: a ghost of it would count in the bar with nothing to see or tap.
  func testALabelWithNoOutlinesIsSkippedAndOneWithSomeIsKept() {
    let body = Data(
      """
      {"ok": true, "shapes": [
        {"kind": "text", "points": [[5, 5]], "text": "👍"},
        {"kind": "text", "points": [[5, 5]], "text": "ok 👍"}
      ]}
      """.utf8)
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: body),
      .shapes([.init(kind: .text, points: [CGPoint(x: 5, y: 5)], text: "ok 👍")], say: "", thread: nil))
  }

  func testNothingToAddIsAnAnswer() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: Data(#"{"ok": true}"#.utf8)), .shapes([], say: "", thread: nil))
  }

  func testTheGhostRequestCarriesThePictureAndItsSize() throws {
    let request = try WhiteboardTurn.suggestRequest(
      title: "Plan", picture: Data([1, 2, 3]), width: 800, height: 600, cockpit: "https://cockpit.example")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/suggest")
    XCTAssertEqual(request.timeoutInterval, 10)
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["image"] as? String, Data([1, 2, 3]).base64EncodedString())
    XCTAssertEqual(body["width"] as? Int, 800)
    XCTAssertEqual(body["height"] as? Int, 600)
    XCTAssertEqual(body["text"] as? String, "Plan")
  }

  func testEveryKindOfStrokeBecomesAShape() throws {
    let body = Data(
      #"""
      {"ok": true, "model": "m", "strokes": [
        {"kind": "line", "x1": 1, "y1": 2, "x2": 3, "y2": 4},
        {"kind": "arrow", "x1": 5, "y1": 6, "x2": 7, "y2": 8, "why": "here"},
        {"kind": "polyline", "points": [[0, 0], [1, 1], [2, 0]]},
        {"kind": "circle", "cx": 50, "cy": 60, "r": 10},
        {"kind": "arc", "cx": 0, "cy": 0, "r": 10, "start": 270, "end": 90},
        {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 20},
        {"kind": "blob"},
        {"kind": "line", "x1": 1}
      ]}
      """#.utf8)
    guard case .shapes(let shapes, let say, let thread) = WhiteboardTurn.answer(status: 200, body: body) else {
      return XCTFail("no shapes")
    }
    XCTAssertEqual(say, "")
    XCTAssertNil(thread)
    XCTAssertEqual(shapes.map(\.kind), [.line, .arrow, .path, .ellipse, .path, .text])
    XCTAssertEqual(shapes[0].points, [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)])
    XCTAssertEqual(shapes[3].points, [CGPoint(x: 40, y: 50), CGPoint(x: 60, y: 70)])
    // 270 to 90 clockwise passes through 0: straight up, right, straight down, on a picture whose y runs down.
    let arc = shapes[4].points
    XCTAssertEqual(arc.first!.y, -10, accuracy: 0.001)
    XCTAssertEqual(arc[arc.count / 2].x, 10, accuracy: 0.001)
    XCTAssertEqual(arc.last!.y, 10, accuracy: 0.001)
    // The baseline at y 40, 20 tall: the label's top is at 20.
    XCTAssertEqual(shapes[5].points, [CGPoint(x: 10, y: 20)])
    XCTAssertEqual(shapes[5].text, "hi")
  }

  func testAskingTooSoonIsNotAFailure() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 429, body: Data(#"{"ok": false, "error": "too soon"}"#.utf8)), .tooSoon)
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
  }

  /// A character Helvetica lacks draws in CoreText's fallback font: an arrow is wider than tall, while the same glyph
  /// id in Helvetica is an unrelated letter taller than wide.
  func testALabelCharacterFromAFallbackFontKeepsItsShape() {
    let points = WhiteboardTurn.lines(
      .init(kind: .text, points: [.zero], text: "→", size: 40), frame: .zero, scale: 1
    ).flatMap { $0 }
    let width = (points.map(\.x).max() ?? 0) - (points.map(\.x).min() ?? 0)
    let height = (points.map(\.y).max() ?? 0) - (points.map(\.y).min() ?? 0)
    XCTAssertGreaterThan(height, 0)
    XCTAssertGreaterThan(width, height * 1.3)
  }

  /// PencilKit's own spline, through the points a kept ghost gets: it must pass every corner the ghost showed.
  func testKeptInkPassesEveryCornerOfTheShape() {
    let shapes: [WhiteboardTurn.Shape] = [
      .init(kind: .rect, points: [.zero, CGPoint(x: 100, y: 100)]),
      .init(kind: .arrow, points: [.zero, CGPoint(x: 90, y: 0)]),
      .init(kind: .text, points: [.zero], text: "HE", size: 40),
      .init(kind: .path, points: [.zero, CGPoint(x: 60, y: 0), CGPoint(x: 60, y: 60)]),
    ]
    for shape in shapes {
      for line in WhiteboardTurn.lines(shape, frame: .zero, scale: 1) {
        let path = PKStrokePath(
          controlPoints: WhiteboardTurn.inkPoints(line).enumerated().map { i, p in
            PKStrokePoint(
              location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: 3.7, height: 3.7), opacity: 1, force: 1,
              azimuth: 0, altitude: .pi / 2)
          }, creationDate: Date())
        let drawn = path.interpolatedPoints(by: .distance(0.25)).map(\.location)
        for corner in line {
          let miss = drawn.map { hypot($0.x - corner.x, $0.y - corner.y) }.min() ?? .infinity
          XCTAssertLessThan(miss, 1.5, "\(shape.kind) at \(corner)")
        }
      }
    }
  }

  func testInkPointsKeepEveryCornerAndStayBoundedOnAnAbsurdEdge() {
    let line = [CGPoint.zero, CGPoint(x: 12, y: 0), CGPoint(x: 12, y: 1)]
    XCTAssertEqual(
      WhiteboardTurn.inkPoints(line),
      [.zero, CGPoint(x: 4, y: 0), CGPoint(x: 8, y: 0), CGPoint(x: 12, y: 0), CGPoint(x: 12, y: 1)])
    let absurd = WhiteboardTurn.inkPoints([.zero, CGPoint(x: 1e300, y: 0)])
    XCTAssertLessThanOrEqual(absurd.count, Int(WhiteboardFrame.side) + 1)
    XCTAssertEqual(absurd.last, CGPoint(x: 1e300, y: 0))
  }

  /// A model's point past anywhere on the board at the finest picture is dropped when read: mapped at a scale under 1
  /// it would be infinite, and keeping that ghost would trap. The sensible part of the shape still draws.
  func testAnAbsurdCoordinateNeverReachesTheInk() throws {
    let body = Data(
      """
      {"ok": true, "shapes": [
        {"kind": "path", "points": [[0, 0], [50, 0], [1e308, 1], [1e308, 2]]},
        {"kind": "line", "points": [[0, 0], [-1e308, 0]]},
        {"kind": "line", "points": [[0, 0], [40000, -40000]]}
      ]}
      """.utf8)
    guard case .shapes(let shapes, _, _) = WhiteboardTurn.answer(status: 200, body: body) else {
      return XCTFail("the answer should still be shapes")
    }
    XCTAssertEqual(
      shapes,
      [
        .init(kind: .path, points: [.zero, CGPoint(x: 50, y: 0)]),
        // The board's far corner at the finest scale: 20,000 points at 2 pixels each.
        .init(kind: .line, points: [.zero, CGPoint(x: 40000, y: -40000)]),
      ])
    let ink = WhiteboardTurn.lines(shapes[0], frame: .zero, scale: 0.5).flatMap { WhiteboardTurn.inkPoints($0) }
    XCTAssertEqual(ink.last, CGPoint(x: 100, y: 0))
  }
}
