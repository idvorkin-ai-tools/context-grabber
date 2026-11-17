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
  /// Igor changed the ink (story 843): strokes added, erased and moved, by name, and the board's revision after.
  case strokesChanged(added: [String], erased: [String], moved: [String], rev: Int, t: Int64)
  /// The lasso's selection, by name (story 844); empty when it was let go.
  case selection(ids: [String], t: Int64)

  public var wire: [String: Any] {
    switch self {
    case .pen(let down, let idleMs, let t):
      return ["type": "pen", "state": down ? "down" : "up", "idle_ms": idleMs, "t": t]
    case .tap(let x, let y, let target, let t):
      let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
      return ["type": "tap", "x": tenth(x), "y": tenth(y), "target_id": target as Any? ?? NSNull(), "t": t]
    case .strokesChanged(let added, let erased, let moved, let rev, let t):
      return ["type": "strokes_changed", "added": added, "erased": erased, "moved": moved, "rev": rev, "t": t]
    case .selection(let ids, let t):
      return ["type": "selection", "ids": ids, "t": t]
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

  /// Any other event, as it happened.
  public mutating func record(_ event: BoardEvent) { add(event) }

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

/// A kept text where its glyphs are, for Larry: its id, words, lettering and box.
struct PlacedText: Equatable, Sendable {
  var text: BoardText
  var x: Double
  var y: Double
  var w: Double
  var h: Double

  /// As the Cockpit's strokes endpoint takes a text (whiteboard_strokes.py): exactly these fields, the box's top-left
  /// and size in board points; any other field, or any other kind without points, is a 400 for the whole snapshot.
  var wire: [String: Any] {
    [
      "kind": "text", "id": text.id, "text": text.text, "font": text.font.strokesFont, "x": x, "y": y, "w": w, "h": h,
      "color": text.color, "t": text.t,
    ]
  }
}

extension WhiteboardStrokes {
  /// The strokes as the Cockpit reads them, at most `maxStrokes`, each kept text of Larry's folded into one
  /// `kind: "text"` entry under its id where its first glyph was, so a later move can name it.
  public static func wire(_ strokes: [Stroke], texts: [BoardText], metas: BoardStrokeMeta = BoardStrokeMeta())
    -> [[String: Any]]
  {
    let plain = { (some: [Stroke]) -> [[String: Any]] in
      // Larry's notes ride on the strokes they belong to, as he wrote them (story 842).
      guard !metas.isEmpty else { return wire(some) }
      return zip(some, wire(some)).map { stroke, entry in
        var entry = entry
        if let meta = metas[stroke.id] { entry["meta"] = meta.object }
        return entry
      }
    }
    guard !texts.isEmpty else { return plain(strokes) }
    let byTime = BoardText.byTime(texts)
    let placed = Dictionary(
      placedTexts(strokes, texts: texts).map { ($0.text.id, $0) }, uniquingKeysWith: { a, _ in a })
    var out: [[String: Any]] = []
    var done = Set<String>()
    for stroke in strokes {
      guard let text = BoardText.owning(stroke.t, in: byTime) else {
        out += plain([stroke])
        continue
      }
      guard done.insert(text.id).inserted, let entry = placed[text.id] else { continue }
      out.append(entry.wire)
      if out.count >= maxStrokes { break }
    }
    return Array(out.prefix(maxStrokes))
  }

  /// Each kept text whose glyphs are on the board, in the order of its first glyph.
  static func placedTexts(_ strokes: [Stroke], texts: [BoardText]) -> [PlacedText] {
    guard !texts.isEmpty else { return [] }
    let byTime = BoardText.byTime(texts)
    var glyphs: [String: [Stroke]] = [:]
    var order: [BoardText] = []
    for stroke in strokes {
      guard let text = BoardText.owning(stroke.t, in: byTime) else { continue }
      if glyphs[text.id] == nil { order.append(text) }
      glyphs[text.id, default: []].append(stroke)
    }
    let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
    return order.map { text in
      let members = glyphs[text.id] ?? []
      let points = members.flatMap(\.points)
      let xs = points.map(\.x)
      let ys = points.map(\.y)
      let (minX, maxX, minY, maxY) = (xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0)
      return PlacedText(text: text, x: tenth(minX), y: tenth(minY), w: tenth(maxX - minX), h: tenth(maxY - minY))
    }
  }
}
