//  A turn on the whiteboard (spec 2026-11-01-whiteboard-shapes-design.md, stories 344 and 349): Claude's ghosts come
//  from `POST /whiteboard/suggest` (the contract is the Cockpit's whiteboard.py), Larry's turn from
//  `POST /whiteboard/turn` (cockpit#85, not built yet). Both answer in the picture's pixels.
//  Here: the request, the answer, and each shape as the ink lines that draw it on the board.

import CoreGraphics
import CoreText
import Foundation

public enum WhiteboardTurn {
  /// Who takes the turn: Claude's ghosts after a pause or spoken words, or Larry's turn when Igor asks for it.
  public enum Who: String, Sendable {
    case claude, larry

    /// How long the app waits: the Cockpit's ghost model takes about 3 s, and Larry much longer.
    public var timeout: TimeInterval { self == .claude ? 10 : 60 }
  }

  public struct Shape: Equatable, Sendable {
    public enum Kind: String, Sendable { case line, arrow, rect, ellipse, path, text }
    public var kind: Kind
    /// In the picture's pixels, origin top-left.
    public var points: [CGPoint]
    public var text: String?
    /// A label's height in the picture's pixels.
    public var size: CGFloat?

    public init(kind: Kind, points: [CGPoint], text: String? = nil, size: CGFloat? = nil) {
      self.kind = kind
      self.points = points
      self.text = text
      self.size = size
    }
  }

  public enum Answer: Equatable, Sendable {
    case shapes([Shape], say: String, thread: String?)
    /// A 429 on a ghost turn: asked within the Cockpit's 2 s, so this turn is skipped and nothing changes.
    case tooSoon
    /// A 4xx: the Cockpit's reason, shown to Igor.
    case refused(status: Int, reason: String)
    /// No answer, a 5xx, or one that can't be read: no turn this time.
    case away(reason: String)
  }

  public static func request(
    who: Who, board: String, title: String, picture: Data, thread: String?, cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("turn"))
    request.httpMethod = "POST"
    request.timeoutInterval = who.timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    var body: [String: Any] = [
      "board": board, "title": title, "who": who.rawValue, "picture": picture.base64EncodedString(),
    ]
    if let thread { body["thread"] = thread }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  /// Claude's ghosts: the picture and its size in pixels, which every stroke comes back in.
  public static func suggestRequest(
    title: String, picture: Data, width: Int, height: Int, cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("suggest"))
    request.httpMethod = "POST"
    request.timeoutInterval = Who.claude.timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // One stroke a line as the model makes it; a Cockpit that doesn't stream answers with one JSON (`WhiteboardStream`).
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    let body: [String: Any] = [
      "image": picture.base64EncodedString(), "width": width, "height": height, "text": title,
      "client": "grabber-native",
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  public static func answer(status: Int?, body: Data?, error: String? = nil, who: Who = .claude) -> Answer {
    guard let status else { return .away(reason: error ?? "no answer") }
    if status == 429, who == .claude { return .tooSoon }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, let json, json["ok"] as? Bool == true {
      let strokes = (json["strokes"] as? [[String: Any]] ?? []).compactMap(shapeJSON(stroke:))
      let shapes = ((json["shapes"] as? [[String: Any]] ?? []) + strokes).compactMap(shape)
      let thread = (json["thread"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      return .shapes(shapes, say: json["say"] as? String ?? "", thread: thread)
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .away(reason: reason)
  }

  /// A stroke from the ghost endpoint as a shape's JSON, so `shape` checks it the same way; nil for a kind it doesn't
  /// know or a number that's missing.
  static func shapeJSON(stroke s: [String: Any]) -> [String: Any]? {
    let n = { (key: String) in s[key] as? Double }
    switch s["kind"] as? String {
    case let kind? where kind == "line" || kind == "arrow":
      guard let x1 = n("x1"), let y1 = n("y1"), let x2 = n("x2"), let y2 = n("y2") else { return nil }
      return ["kind": kind, "points": [[x1, y1], [x2, y2]]]
    case "polyline":
      return ["kind": "path", "points": s["points"] ?? []]
    case "circle":
      guard let cx = n("cx"), let cy = n("cy"), let r = n("r") else { return nil }
      return ["kind": "ellipse", "points": [[cx - r, cy - r], [cx + r, cy + r]]]
    case "arc":
      guard let cx = n("cx"), let cy = n("cy"), let r = n("r"), let start = n("start"), let end = n("end") else {
        return nil
      }
      // Degrees clockwise from +x on a picture whose y runs down, always the clockwise way from start to end.
      let sweep = (end - start).truncatingRemainder(dividingBy: 360)
      let degrees = sweep < 0 ? sweep + 360 : sweep
      let steps = max(2, Int(degrees / 7.5))
      return [
        "kind": "path",
        "points": (0...steps).map { i -> [Double] in
          let a = (start + degrees * Double(i) / Double(steps)) * .pi / 180
          return [cx + r * cos(a), cy + r * sin(a)]
        },
      ]
    case "label":
      // The Cockpit's x, y is the text's baseline; a shape's text hangs from its top-left.
      guard let x = n("x"), let y = n("y") else { return nil }
      let size = n("size") ?? 18
      return ["kind": "text", "points": [[x, y - labelAscent * size]], "text": s["text"] ?? "", "size": size]
    default:
      return nil
    }
  }

  /// One shape from the answer; nil for a kind it doesn't know, too few points to draw, or a label with no outlines.
  static func shape(_ json: [String: Any]) -> Shape? {
    guard let kind = (json["kind"] as? String).flatMap(Shape.Kind.init(rawValue:)) else { return nil }
    let points = (json["points"] as? [[Any]] ?? []).compactMap { pair -> CGPoint? in
      guard pair.count == 2, let x = number(pair[0]), let y = number(pair[1]) else { return nil }
      return CGPoint(x: x, y: y)
    }
    let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if kind == .text {
      guard !points.isEmpty, let text, !glyphLines(text, topLeft: .zero, height: 28).isEmpty else { return nil }
    } else {
      guard points.count >= 2 else { return nil }
    }
    return Shape(kind: kind, points: points, text: text, size: json["size"].flatMap(number))
  }

  /// A number within reach of a picture: no point on the board is further out in pixels than its side at the finest
  /// scale. Past that, a model's coordinate could map to infinity on the board and trap when its ghost is kept.
  private static func number(_ any: Any) -> CGFloat? {
    guard let n = any as? NSNumber, abs(n.doubleValue) <= WhiteboardFrame.side * WhiteboardFrame.maxScale else {
      return nil
    }
    return CGFloat(n.doubleValue)
  }

  /// The ink lines that draw `shape` on the board, given the picture's frame (`WhiteboardFrame.export`).
  public static func lines(_ shape: Shape, frame: CGRect, scale: CGFloat) -> [[CGPoint]] {
    let board = { (p: CGPoint) in CGPoint(x: frame.minX + p.x / scale, y: frame.minY + p.y / scale) }
    let p = shape.points.map(board)
    switch shape.kind {
    case .line: return [[p[0], p[1]]]
    case .path: return [p]
    case .rect:
      let r = CGRect(
        x: min(p[0].x, p[1].x), y: min(p[0].y, p[1].y), width: abs(p[1].x - p[0].x), height: abs(p[1].y - p[0].y))
      return [
        [
          r.origin, CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
          r.origin,
        ]
      ]
    case .ellipse:
      let c = CGPoint(x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2)
      let rx = abs(p[1].x - p[0].x) / 2
      let ry = abs(p[1].y - p[0].y) / 2
      return [
        (0...48).map { i in
          let a = CGFloat(i) / 48 * 2 * .pi
          return CGPoint(x: c.x + rx * cos(a), y: c.y + ry * sin(a))
        }
      ]
    case .arrow:
      let (a, b) = (p[0], p[1])
      let length = hypot(b.x - a.x, b.y - a.y)
      guard length > 0 else { return [[a, b]] }
      let head = min(24, length / 3)
      let angle = atan2(b.y - a.y, b.x - a.x)
      let wing = { (turn: CGFloat) in
        CGPoint(x: b.x - head * cos(angle + turn), y: b.y - head * sin(angle + turn))
      }
      return [[a, b], [wing(.pi / 6), b, wing(-.pi / 6)]]
    case .text:
      let size = (shape.size ?? 28) / scale
      let height = max(8, size)
      let top = CGPoint(x: p[0].x, y: p[0].y + labelAscent * (size - height))
      return glyphLines(shape.text ?? "", topLeft: top, height: height)
    }
  }

  /// Whether `point` is within `tolerance` of any of `lines`: a tap on a ghost.
  public static func hit(_ lines: [[CGPoint]], at point: CGPoint, tolerance: CGFloat) -> Bool {
    for line in lines {
      for (a, b) in zip(line, line.dropFirst()) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let span = dx * dx + dy * dy
        let t = span == 0 ? 0 : max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / span))
        if hypot(a.x + t * dx - point.x, a.y + t * dy - point.y) <= tolerance { return true }
      }
    }
    return false
  }

  /// `line` with a point about every `spacing` board points, the most a board-sized edge needs. PencilKit treats a
  /// stroke's points as spline control points, so a corner between far-apart points would be cut short; at 4 points it
  /// misses by under a point.
  public static func inkPoints(_ line: [CGPoint], spacing: CGFloat = 4) -> [CGPoint] {
    var out = Array(line.prefix(1))
    for (a, b) in zip(line, line.dropFirst()) {
      let steps = Int(min(hypot(b.x - a.x, b.y - a.y) / spacing, WhiteboardFrame.side).rounded(.up))
      if steps > 1 {
        for i in 1..<steps {
          let t = CGFloat(i) / CGFloat(steps)
          out.append(CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
        }
      }
      out.append(b)
    }
    return out
  }

  /// How far a label's baseline sits below its top, as a share of its size.
  private static let labelAscent = CTFontGetAscent(CTFontCreateWithName("Helvetica" as CFString, 100, nil)) / 100

  /// A label as the outlines of its letters (the system font), flattened into lines PencilKit can draw.
  static func glyphLines(_ text: String, topLeft: CGPoint, height: CGFloat) -> [[CGPoint]] {
    let font = CTFontCreateWithName("Helvetica" as CFString, height, nil)
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    let ascent = labelAscent * height
    var out: [[CGPoint]] = []
    for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
      let count = CTRunGetGlyphCount(run)
      var glyphs = [CGGlyph](repeating: 0, count: count)
      var positions = [CGPoint](repeating: .zero, count: count)
      CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
      CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
      // CoreText's fallback for a character Helvetica lacks: the run's glyph ids index the run's own font.
      // swiftlint:disable:next force_cast
      let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
      for (glyph, at) in zip(glyphs, positions) {
        guard let path = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
        // Glyphs are drawn y-up from the baseline; the board is y-down from the label's top.
        let place = { (q: CGPoint) in CGPoint(x: topLeft.x + at.x + q.x, y: topLeft.y + ascent - q.y) }
        out += flatten(path).map { $0.map(place) }
      }
    }
    return out
  }

  /// A path's subpaths as polylines, curves sampled in eight steps.
  static func flatten(_ path: CGPath) -> [[CGPoint]] {
    var out: [[CGPoint]] = []
    var current: [CGPoint] = []
    var start = CGPoint.zero
    let steps = 8
    path.applyWithBlock { element in
      let e = element.pointee
      // A subpath that goes on after a close starts where the last one started.
      if current.isEmpty, e.type != .moveToPoint { current = [start] }
      let last = current.last ?? start
      switch e.type {
      case .moveToPoint:
        if current.count > 1 { out.append(current) }
        start = e.points[0]
        current = [start]
      case .addLineToPoint:
        current.append(e.points[0])
      case .addQuadCurveToPoint:
        let (c, end) = (e.points[0], e.points[1])
        for i in 1...steps {
          let t = CGFloat(i) / CGFloat(steps)
          let u = 1 - t
          current.append(
            CGPoint(
              x: u * u * last.x + 2 * u * t * c.x + t * t * end.x, y: u * u * last.y + 2 * u * t * c.y + t * t * end.y))
        }
      case .addCurveToPoint:
        let (c1, c2, end) = (e.points[0], e.points[1], e.points[2])
        for i in 1...steps {
          let t = CGFloat(i) / CGFloat(steps)
          let u = 1 - t
          let x = u * u * u * last.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x
          let y = u * u * u * last.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
          current.append(CGPoint(x: x, y: y))
        }
      case .closeSubpath:
        current.append(start)
        if current.count > 1 { out.append(current) }
        current = []
      @unknown default:
        break
      }
    }
    if current.count > 1 { out.append(current) }
    return out
  }
}
