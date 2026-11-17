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
  /// A finger in the left margin (story 849): where it went down on the board, and how far a drag went.
  case margin(gesture: BoardMargin.Gesture, y: CGFloat, dy: CGFloat, t: Int64)
  /// The part of the board on screen once the view rests (story 850), in board points, and the zoom.
  case viewport(y: CGFloat, h: CGFloat, scale: CGFloat, t: Int64)
  /// Igor undid a batch of Larry's, by its label (story 851).
  case undo(label: String, t: Int64)
  /// A tap on one of Larry's controls (story 846): its tap_event as he wrote it.
  case overlayTap(id: String, event: BoardMeta?, t: Int64)

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
    case .margin(let gesture, let y, let dy, let t):
      let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
      return ["type": "margin", "gesture": gesture.rawValue, "y": tenth(y), "dy": tenth(dy), "t": t]
    case .viewport(let y, let h, let scale, let t):
      let tenth = { (v: CGFloat) in Double((v * 10).rounded() / 10) }
      return [
        "type": "viewport", "y": tenth(y), "h": tenth(h), "scale": Double((scale * 1000).rounded() / 1000), "t": t,
      ]
    case .undo(let label, let t):
      return ["type": "undo", "label": label, "t": t]
    case .overlayTap(let id, let event, let t):
      // The Cockpit wakes Larry for an `overlay_tap` naming its `target_id`; his own event rides along as written.
      var out: [String: Any] = ["type": "overlay_tap", "target_id": id, "overlay_id": id, "t": t]
      if let his = event?.object { out["event"] = his }
      return out
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

  /// Events taken for a send that didn't get through: back in front of any since, under the cap.
  public mutating func restore(_ taken: (events: [BoardEvent], dropped: Int)) {
    list = taken.events + list
    dropped += taken.dropped
    if list.count > Self.cap {
      dropped += list.count - Self.cap
      list.removeFirst(list.count - Self.cap)
    }
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

  /// The Cockpit's caps on `POST /whiteboard/events`: events per post, bytes per event, bytes per body.
  public static let maxEvents = 200
  public static let maxEventBytes = 8 * 1024
  public static let maxBodyBytes = 256 * 1024
  /// What the events may take of a body, leaving room for the rest of the message (its picture goes separately).
  static let eventBudget = maxBodyBytes - 16 * 1024

  /// Within the Cockpit's caps: an event over its size is dropped, and the oldest go until the rest fit. Every one
  /// dropped is counted in `events_dropped`.
  public var wire: [String: Any] {
    let sized = events.map(\.wire).map { ($0, Self.bytes($0)) }
    var kept = sized.filter { $0.1 <= Self.maxEventBytes }
    var total = kept.reduce(0) { $0 + $1.1 + 1 }
    while !kept.isEmpty, kept.count > Self.maxEvents || total > Self.eventBudget {
      total -= kept.removeFirst().1 + 1
    }
    var out: [String: Any] = ["rev": rev, "events": kept.map(\.0)]
    if let opResult { out["op_result"] = opResult.wire }
    let dropped = eventsDropped + sized.count - kept.count
    if dropped > 0 { out["events_dropped"] = dropped }
    return out
  }

  private static func bytes(_ event: [String: Any]) -> Int {
    (try? JSONSerialization.data(withJSONObject: event, options: [.sortedKeys]).count) ?? Int.max
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
