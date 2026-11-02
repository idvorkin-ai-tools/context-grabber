//  A turn on the whiteboard (spec 2026-11-01-whiteboard-shapes-design.md, stories 344 and 349; the Cockpit half is
//  cockpit#85): the board's picture goes to `POST /whiteboard/turn`, and shapes come back in the picture's pixels.
//  Here: the request, the answer, and each shape as the ink lines that draw it on the board.

import CoreGraphics
import CoreText
import Foundation

public enum WhiteboardTurn {
  /// Who takes the turn: Claude's ghosts after a pause, or Larry's turn when Igor asks for it.
  public enum Who: String, Sendable {
    case claude, larry

    /// How long the app waits: a ghost that comes late lands on a drawing that has moved on.
    public var timeout: TimeInterval { self == .claude ? 3 : 60 }
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

  public static func answer(status: Int?, body: Data?, error: String? = nil) -> Answer {
    guard let status else { return .away(reason: error ?? "no answer") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, let json, json["ok"] as? Bool == true {
      let shapes = (json["shapes"] as? [[String: Any]] ?? []).compactMap(shape)
      let thread = (json["thread"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      return .shapes(shapes, say: json["say"] as? String ?? "", thread: thread)
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .away(reason: reason)
  }

  /// One shape from the answer; nil for a kind it doesn't know or too few points to draw.
  static func shape(_ json: [String: Any]) -> Shape? {
    guard let kind = (json["kind"] as? String).flatMap(Shape.Kind.init(rawValue:)) else { return nil }
    let points = (json["points"] as? [[Any]] ?? []).compactMap { pair -> CGPoint? in
      guard pair.count == 2, let x = number(pair[0]), let y = number(pair[1]) else { return nil }
      return CGPoint(x: x, y: y)
    }
    let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if kind == .text {
      guard !points.isEmpty, let text, !text.isEmpty else { return nil }
    } else {
      guard points.count >= 2 else { return nil }
    }
    return Shape(kind: kind, points: points, text: text, size: json["size"].flatMap(number))
  }

  private static func number(_ any: Any) -> CGFloat? {
    guard let n = any as? NSNumber, n.doubleValue.isFinite else { return nil }
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
      let height = max(8, (shape.size ?? 28) / scale)
      return glyphLines(shape.text ?? "", topLeft: p[0], height: height)
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

  /// A label as the outlines of its letters (the system font), flattened into lines PencilKit can draw.
  static func glyphLines(_ text: String, topLeft: CGPoint, height: CGFloat) -> [[CGPoint]] {
    let font = CTFontCreateWithName("Helvetica" as CFString, height, nil)
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    let ascent = CTFontGetAscent(font)
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
