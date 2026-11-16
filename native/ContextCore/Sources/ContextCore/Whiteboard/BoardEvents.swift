//  What the board tells Larry on each turn besides its picture and strokes (spec 2026-11-16-whiteboard-board-ops-design.md,
//  stories 817, 818): its revision, what came of his last change, the Pencil's downs and ups and the taps since the last
//  turn; and his kept texts, which go back to him in `strokes` as one text each, under his id.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardEvent: Equatable, Codable, Sendable {
  /// The Pencil went down or up, at `t` (unix ms). `idleMs`: on a down, how long it had been up; on an up, how long it was
  /// down. 0 for the first one the board saw.
  case pen(down: Bool, idleMs: Int, t: Int64)
  /// A finger tap at a board point; `target` is the mark it landed on (a ghost's id, a kept text's id), or nil.
  case tap(x: CGFloat, y: CGFloat, target: String?, t: Int64)

  public var wire: [String: Any] {
    switch self {
    case .pen(let down, let idleMs, let t):
      return ["type": "pen", "state": down ? "down" : "up", "idle_ms": idleMs, "t": t]
    case .tap(let x, let y, let target, let t):
      let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
      return ["type": "tap", "x": tenth(x), "y": tenth(y), "target_id": target as Any? ?? NSNull(), "t": t]
    }
  }
}

/// The events since the last turn, at most `cap`: a long drawing session keeps its newest.
public struct BoardEvents: Equatable, Sendable {
  public static let cap = 100

  public private(set) var list: [BoardEvent] = []
  /// Dropped since the last `take` to stay under the cap.
  public private(set) var dropped = 0
  private var lastPen: (down: Bool, t: Int64)?

  public init() {}

  public static func == (a: BoardEvents, b: BoardEvents) -> Bool { a.list == b.list && a.dropped == b.dropped }

  /// The Pencil went down or up. A second down without an up between (two touches) is one.
  public mutating func pen(down: Bool, t: Int64) {
    if let lastPen, lastPen.down == down { return }
    let idle = lastPen.map { Int(max(0, t - $0.t)) } ?? 0
    lastPen = (down, t)
    add(.pen(down: down, idleMs: idle, t: t))
  }

  public mutating func tap(at point: CGPoint, target: String?, t: Int64) {
    add(.tap(x: point.x, y: point.y, target: target, t: t))
  }

  /// The events for a turn; the next turn gets only what happens after.
  public mutating func take() -> (events: [BoardEvent], dropped: Int) {
    defer {
      list = []
      dropped = 0
    }
    return (list, dropped)
  }

  private mutating func add(_ event: BoardEvent) {
    list.append(event)
    if list.count > Self.cap {
      dropped += list.count - Self.cap
      list.removeFirst(list.count - Self.cap)
    }
  }
}

/// The board's half of a turn, on its chat message to Larry (never on `POST /whiteboard/strokes`).
public struct BoardTurnReport: Equatable, Codable, Sendable {
  public var rev: Int
  public var opResult: BoardOps.Result?
  public var events: [BoardEvent]
  public var eventsDropped: Int

  public init(rev: Int, opResult: BoardOps.Result? = nil, events: [BoardEvent] = [], eventsDropped: Int = 0) {
    self.rev = rev
    self.opResult = opResult
    self.events = events
    self.eventsDropped = eventsDropped
  }

  public var wire: [String: Any] {
    var out: [String: Any] = ["rev": rev, "events": events.map(\.wire)]
    if let opResult { out["op_result"] = opResult.wire }
    if eventsDropped > 0 { out["events_dropped"] = eventsDropped }
    return out
  }
}

/// A text of Larry's that Igor kept: its glyph strokes were all made at `t`, which is how the board knows them again.
public struct BoardText: Equatable, Codable, Sendable {
  public var id: String
  /// The glyph strokes' creation time, unix ms.
  public var t: Int64
  public var text: String
  public var font: BoardOps.Font
  public var size: Double
  /// `#rrggbb`.
  public var color: String

  public init(id: String, t: Int64, text: String, font: BoardOps.Font, size: Double, color: String) {
    self.id = id
    self.t = t
    self.text = text
    self.font = font
    self.size = size
    self.color = color
  }

  /// A creation time in ms exactly as a kept text's glyphs go out: whole milliseconds, so the time read back from the
  /// strokes is the one recorded.
  public static func time(_ date: Date) -> (date: Date, t: Int64) {
    let t = Int64((date.timeIntervalSince1970 * 1000).rounded())
    return (Date(timeIntervalSince1970: Double(t) / 1000), t)
  }

  /// The kept text a stroke made at `t` belongs to. A millisecond either way still matches: the time is read back from
  /// a saved drawing as a double and truncated.
  public static func owning(_ t: Int64?, in byTime: [Int64: BoardText]) -> BoardText? {
    guard let t else { return nil }
    return byTime[t] ?? byTime[t - 1] ?? byTime[t + 1]
  }

  public static func byTime(_ texts: [BoardText]) -> [Int64: BoardText] {
    Dictionary(texts.map { ($0.t, $0) }, uniquingKeysWith: { _, new in new })
  }
}

extension WhiteboardStrokes {
  /// The strokes as the Cockpit reads them, at most `maxStrokes`, a kept text's glyphs folded into one entry where its
  /// first glyph was: `kind: "text"`, its id, words, lettering and box, so a later move can name it.
  public static func wire(_ strokes: [Stroke], texts: [BoardText]) -> [[String: Any]] {
    guard !texts.isEmpty else { return wire(strokes) }
    let byTime = BoardText.byTime(texts)
    var glyphs: [String: [Stroke]] = [:]
    for stroke in strokes {
      if let text = BoardText.owning(stroke.t, in: byTime) { glyphs[text.id, default: []].append(stroke) }
    }
    var out: [[String: Any]] = []
    var folded = Set<String>()
    for stroke in strokes {
      guard let text = BoardText.owning(stroke.t, in: byTime) else {
        out += wire([stroke])
        continue
      }
      guard folded.insert(text.id).inserted, let members = glyphs[text.id] else { continue }
      out.append(textEntry(text, members))
      if out.count >= maxStrokes { break }
    }
    return Array(out.prefix(maxStrokes))
  }

  static func textEntry(_ text: BoardText, _ glyphs: [Stroke]) -> [String: Any] {
    let points = glyphs.flatMap(\.points)
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    let (minX, maxX, minY, maxY) = (xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0)
    let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
    let width = glyphs.isEmpty ? 0 : glyphs.map(\.width).reduce(0, +) / CGFloat(glyphs.count)
    return [
      "id": text.id, "kind": "text", "text": text.text, "font": text.font.rawValue, "size": text.size,
      "color": text.color, "width": Double(width), "tool": "text", "t": text.t,
      "x": tenth(minX), "y": tenth(minY), "w": tenth(maxX - minX), "h": tenth(maxY - minY),
      "points": [[tenth(minX), tenth(minY)], [tenth(maxX), tenth(maxY)]],
    ]
  }
}
