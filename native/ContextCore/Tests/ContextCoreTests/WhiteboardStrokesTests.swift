import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import ContextCore

/// Story 419 (cockpit-f7c): the board's strokes go to the Cockpit before each picture, in board points, with ids the
/// Cockpit can tell apart across sends.
final class WhiteboardStrokesTests: XCTestCase {
  private let frame = CGRect(x: 9597, y: 9421, width: 694, height: 165)
  private let points = [CGPoint(x: 9640.04, y: 9460), CGPoint(x: 9700, y: 9462.26), CGPoint(x: 9760, y: 9470)]

  func testAnIdIsStableAndTellsStrokesApart() {
    let a = WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_070_000)
    XCTAssertEqual(a.count, 16)
    XCTAssertEqual(a, WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_070_000), "the same again")
    XCTAssertEqual(
      a,
      WhiteboardStrokes.id(
        points: points.map { CGPoint(x: $0.x + 0.001, y: $0.y) }, color: "#000000", t: 1_762_189_070_000),
      "a thousandth of a point is the same ink")
    XCTAssertNotEqual(
      a, WhiteboardStrokes.id(points: Array(points.dropLast()), color: "#000000", t: 1_762_189_070_000))
    XCTAssertNotEqual(a, WhiteboardStrokes.id(points: points, color: "#1e6fd9", t: 1_762_189_070_000))
    XCTAssertNotEqual(a, WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_071_000))
    XCTAssertEqual(
      WhiteboardStrokes.id(points: points, color: "#1E6FD9", t: nil),
      WhiteboardStrokes.id(points: points, color: "#1e6fd9", t: nil), "colour case doesn't count")
  }

  func testColourAndToolAreWhatTheCockpitTakes() {
    XCTAssertEqual(WhiteboardStrokes.hex(red: 0, green: 0, blue: 0), "#000000")
    XCTAssertEqual(WhiteboardStrokes.hex(red: 0.118, green: 0.435, blue: 0.851), "#1e6fd9")
    XCTAssertEqual(WhiteboardStrokes.hex(red: 2, green: -1, blue: 1), "#ff00ff", "clamped")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.pen"), "pen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.fountainPen"), "fountainpen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.marker"), "marker")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: ""), "pen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "x.9lives"), "pen", "must start with a letter")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "x.averyveryverylongtoolname"), "averyveryverylon")
  }

  func testThinningKeepsTheEndsAndTheCap() {
    let many = (0..<10_000).map { CGPoint(x: CGFloat($0), y: 0.123) }
    let thinned = WhiteboardStrokes.thin(many)
    XCTAssertLessThanOrEqual(thinned.count, WhiteboardStrokes.maxPoints)
    XCTAssertEqual(thinned.first, CGPoint(x: 0, y: 0.1))
    XCTAssertEqual(thinned.last, CGPoint(x: 9999, y: 0.1))
    XCTAssertEqual(WhiteboardStrokes.thin([CGPoint(x: 1.26, y: 2)]), [CGPoint(x: 1.3, y: 2)], "a dot stays a dot")
    XCTAssertEqual(WhiteboardStrokes.thin(points, max: 2), [CGPoint(x: 9640, y: 9460), CGPoint(x: 9760, y: 9470)])
  }

  func testTheRequestCarriesThePictureAndTheStrokes() throws {
    let picture = WhiteboardPicture(board: "b1", title: "Plan", rect: frame, scale: 2, pictureID: "p1")
    let strokes = [
      WhiteboardStrokes.Stroke(id: "s1", t: 7, points: points),
      WhiteboardStrokes.Stroke(id: "s2", color: "#1e6fd9", width: 3.7, tool: "marker", points: [points[0]]),
    ]
    let request = try WhiteboardStrokes.request(
      picture: picture, strokes: WhiteboardStrokes.wire(strokes), cockpit: "https://c.example")
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/whiteboard/strokes")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["picture_id"] as? String, "p1")
    XCTAssertEqual(body["frame"] as? [String: Double], ["x": 9597, "y": 9421, "w": 694, "h": 165, "scale": 2])
    XCTAssertNil(body["title"], "the title is the chat message's, not the strokes'")
    let sent = try XCTUnwrap(body["strokes"] as? [[String: Any]])
    XCTAssertEqual(sent.count, 2)
    XCTAssertEqual(sent[0]["id"] as? String, "s1")
    XCTAssertEqual(sent[0]["t"] as? Int, 7)
    XCTAssertEqual(sent[0]["color"] as? String, "#000000")
    XCTAssertEqual(sent[0]["tool"] as? String, "pen")
    XCTAssertEqual(sent[0]["width"] as? Double, 3)
    XCTAssertEqual(sent[0]["points"] as? [[Double]], [[9640, 9460], [9700, 9462.3], [9760, 9470]])
    XCTAssertNil(sent[1]["t"])
    XCTAssertEqual(sent[1]["width"] as? Double, 3.7)
    XCTAssertEqual(sent[1]["points"] as? [[Double]], [[9640, 9460]])
  }

  func testWireStopsAtTheCockpitsCap() {
    let strokes = (0..<(WhiteboardStrokes.maxStrokes + 5)).map {
      WhiteboardStrokes.Stroke(id: "s\($0)", points: [.zero])
    }
    XCTAssertEqual(WhiteboardStrokes.wire(strokes).count, WhiteboardStrokes.maxStrokes)
  }

  func testTheAnswerIsStoredRefusedOrAway() {
    XCTAssertEqual(
      WhiteboardStrokes.answer(
        status: 200, body: Data(#"{"ok": true, "count": 73, "new": 2, "erased": 1}"#.utf8)),
      .stored(count: 73, new: 2, erased: 1))
    XCTAssertEqual(
      WhiteboardStrokes.answer(
        status: 400, body: Data(#"{"ok": false, "error": "stroke 3: a point is off the board"}"#.utf8)),
      .refused(status: 400, reason: "stroke 3: a point is off the board"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: 413, body: nil), .refused(status: 413, reason: "HTTP 413"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: 503, body: Data("<html>".utf8)), .away(reason: "HTTP 503"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: nil, body: nil, error: "offline"), .away(reason: "offline"))
    XCTAssertEqual(
      WhiteboardStrokes.answer(status: 200, body: Data(#"{"ok": false}"#.utf8)), .away(reason: "HTTP 200"),
      "a 200 that says no is no answer")
    let fields = WhiteboardStrokes.logFields(.stored(count: 73, new: 2, erased: 1))
    XCTAssertEqual(fields["strokes"] as? Int, 73)
    XCTAssertEqual(fields["strokes_ok"] as? Bool, true)
    XCTAssertEqual(WhiteboardStrokes.logFields(.away(reason: "x"))["strokes_ok"] as? Bool, false)
  }

  // MARK: Through the outbox (Send to Larry)

  /// A 1 x 1 PNG: enough for the sender's image rules.
  private func png() throws -> Data {
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try XCTUnwrap(context.makeImage())
    let out = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return out as Data
  }

  func testStrokesWaitBesideThePictureAndGoBeforeItWhateverTheCockpitSays() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = try png()
    draft.text = "Board, Nov 3"
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "Board, Nov 3", rect: frame, scale: 2, pictureID: "p1")
    draft.strokes = try JSONSerialization.data(
      withJSONObject: WhiteboardStrokes.wire([WhiteboardStrokes.Stroke(id: "s1", points: points)]))
    let item = try draft.save(to: store, at: 1, id: "m1")
    XCTAssertEqual(item.strokesFile, "m1.strokes.json")
    XCTAssertEqual(store.item("m1")?.strokesFile, "m1.strokes.json", "the file's name survives the outbox")
    XCTAssertNotNil(store.strokes(of: item))

    let calls = Calls()
    let sender = InboxSender(store: store, cockpit: "https://c.example") { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: request.httpBody)
      let (status, body): (Int, String) =
        switch url.path {
        case "/attachments": (200, #"{"ok": true, "ref": "r1"}"#)
        case "/whiteboard/strokes": (500, "boom")
        default: (200, #"{"ok": true, "thread": "t1"}"#)
        }
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
      )
    }
    var lines: [[String: Any]] = []
    let report = await sender.sendWaiting { _, fields in lines.append(fields) }
    XCTAssertEqual(report.sent, ["m1"], "a 500 to the strokes never stops the picture")
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/whiteboard/strokes", "/chat"], "strokes before the message")
    let sent = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(await calls.bodies["/whiteboard/strokes"])) as? [String: Any])
    XCTAssertEqual(sent["board"] as? String, "b1")
    XCTAssertEqual(sent["picture_id"] as? String, "p1")
    XCTAssertEqual((sent["strokes"] as? [[String: Any]])?.first?["id"] as? String, "s1")
    XCTAssertEqual(lines.first?["action"] as? String, "sent")
    XCTAssertEqual(lines.first?["strokes_ok"] as? Bool, false)
    XCTAssertEqual(lines.first?["strokes_reason"] as? String, "HTTP 500")

    try store.delete(try XCTUnwrap(store.item("m1")))
    XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("m1.strokes.json").path))
  }

  func testAPictureWithoutStrokesSendsAsBefore() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = try png()
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "T", rect: frame, scale: 2, pictureID: "p1")
    let item = try draft.save(to: store, at: 1, id: "m2")
    XCTAssertNil(item.strokesFile)
    let calls = Calls()
    let sender = InboxSender(store: store, cockpit: "https://c.example") { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: nil)
      let body = url.path == "/attachments" ? #"{"ok": true, "ref": "r1"}"# : #"{"ok": true, "thread": "t1"}"#
      return (
        Data(body.utf8), try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      )
    }
    var lines: [[String: Any]] = []
    _ = await sender.sendWaiting { _, fields in lines.append(fields) }
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/chat"])
    XCTAssertNil(lines.first?["strokes_ok"])
  }
}

private actor Calls {
  var paths: [String] = []
  var bodies: [String: Data] = [:]

  func add(_ path: String, body: Data?) {
    paths.append(path)
    if let body { bodies[path] = body }
  }
}
