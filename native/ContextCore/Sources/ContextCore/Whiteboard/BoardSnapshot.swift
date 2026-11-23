//  A board as Larry gets it, for replaying his changes off the iPad (#936, story 990): the strokes the board posts with
//  each picture (`POST /whiteboard/strokes`, or the Cockpit's stored snapshot of it), plus what only the iPad knows and
//  a replay needs: the board's revision, his text ghosts not yet kept, and what Igor moved since an older look. Pure:
//  the harness (`BoardReplay`, the `board-ops-harness` tool) and the host tests read and write it.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct BoardSnapshot: Equatable, Sendable {
  /// One stroke of ink, as the strokes wire carries it.
  public struct Ink: Equatable, Sendable {
    public var id: String
    public var t: Int64?
    public var color: String
    public var width: CGFloat
    public var tool: String
    public var points: [CGPoint]
    public var hidden: Bool
    public var meta: BoardMeta?

    public init(
      id: String, t: Int64? = nil, color: String = "#000000", width: CGFloat = 3, tool: String = "pen",
      points: [CGPoint], hidden: Bool = false, meta: BoardMeta? = nil
    ) {
      self.id = id
      self.t = t
      self.color = color
      self.width = width
      self.tool = tool
      self.points = points
      self.hidden = hidden
      self.meta = meta
    }

    /// Its ink's box: its points widened by half its pen.
    public var bounds: CGRect {
      guard let first = points.first else { return .null }
      let box = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) {
        $0.union(CGRect(origin: $1, size: .zero))
      }
      return box.insetBy(dx: -width / 2, dy: -width / 2)
    }
  }

  /// A text of Larry's that Igor kept, as the wire folds its glyphs: its box and words.
  public struct Kept: Equatable, Sendable {
    public var id: String
    public var text: String
    public var font: BoardOps.Font
    public var box: CGRect
    public var color: String
    public var t: Int64
    /// Its letters' height, when known (the wire carries only the box).
    public var size: CGFloat?
    public var meta: BoardMeta?

    public init(
      id: String, text: String, font: BoardOps.Font = .plain, box: CGRect, color: String, t: Int64,
      size: CGFloat? = nil, meta: BoardMeta? = nil
    ) {
      self.id = id
      self.text = text
      self.font = font
      self.box = box
      self.color = color
      self.t = t
      self.size = size
      self.meta = meta
    }

    /// The mark that draws it, with a frame at the board's origin and a scale of 1.
    public var shape: WhiteboardTurn.Shape {
      BoardOps.Text(
        id: id, x: box.minX, y: box.minY, text: text, font: font, size: size ?? box.height,
        color: UInt32(color.dropFirst(), radix: 16)
      ).shape
    }
  }

  /// A change Igor made after an older look: the revision it made and the names it moved or erased (story 961).
  public struct Touch: Equatable, Sendable {
    public var rev: Int
    public var ids: [String]

    public init(rev: Int, ids: [String]) {
      self.rev = rev
      self.ids = ids
    }
  }

  public var board: String
  /// The board's revision this snapshot is at; nil when it doesn't say (the replay takes the batch's `base_rev`).
  public var rev: Int?
  /// The column's page count; nil works it out from the ink.
  public var pages: Int?
  public var ink: [Ink]
  public var texts: [Kept]
  /// Larry's text ghosts showing and not yet kept.
  public var ghosts: [BoardOps.Text]
  public var touched: [Touch]

  public init(
    board: String, rev: Int? = nil, pages: Int? = nil, ink: [Ink] = [], texts: [Kept] = [],
    ghosts: [BoardOps.Text] = [], touched: [Touch] = []
  ) {
    self.board = board
    self.rev = rev
    self.pages = pages
    self.ink = ink
    self.texts = texts
    self.ghosts = ghosts
    self.touched = touched
  }

  public struct Unreadable: Error, CustomStringConvertible {
    public let description: String
  }

  // MARK: The wire

  /// The strokes JSON: `{board, strokes: [...]}` as the board posts it or the Cockpit stores it, with the harness's own
  /// `rev`, `pages`, `ghosts` (each an `add_text` op as Larry sends it) and `touched` (`[{rev, ids}]`).
  public init(json any: Any) throws {
    guard let json = any as? [String: Any] else { throw Unreadable(description: "a snapshot is a JSON object") }
    guard let board = json["board"] as? String else { throw Unreadable(description: "the snapshot has no board") }
    self.init(board: board)
    rev = JSONNumber(json["rev"])?.intValue
    pages = JSONNumber(json["pages"])?.intValue
    for (index, entry) in (json["strokes"] as? [Any] ?? []).enumerated() {
      guard let entry = entry as? [String: Any], let id = entry["id"] as? String else {
        throw Unreadable(description: "stroke \(index) has no id")
      }
      let t = JSONNumber(entry["t"])?.int64Value
      let color = entry["color"] as? String ?? "#000000"
      let meta = BoardMeta(entry["meta"])
      if entry["kind"] as? String == "text" {
        let n = { (key: String) in CGFloat(JSONNumber(entry[key])?.doubleValue ?? 0) }
        texts.append(
          Kept(
            id: id, text: entry["text"] as? String ?? "",
            font: (entry["font"] as? String).map { $0 == "hand" ? .hand : .plain } ?? .plain,
            box: CGRect(x: n("x"), y: n("y"), width: n("w"), height: n("h")), color: color, t: t ?? 0,
            size: JSONNumber(entry["size"]).map { CGFloat($0.doubleValue) }, meta: meta))
        continue
      }
      let points = (entry["points"] as? [[Any]] ?? []).compactMap { pair -> CGPoint? in
        guard pair.count == 2, let x = JSONNumber(pair[0]), let y = JSONNumber(pair[1]) else { return nil }
        return CGPoint(x: x.doubleValue, y: y.doubleValue)
      }
      guard !points.isEmpty else { throw Unreadable(description: "stroke \(id) has no points") }
      ink.append(
        Ink(
          id: id, t: t, color: color, width: CGFloat(JSONNumber(entry["width"])?.doubleValue ?? 3),
          tool: entry["tool"] as? String ?? "pen", points: points, hidden: entry["hidden"] as? Bool ?? false,
          meta: meta))
    }
    for (index, ghost) in (json["ghosts"] as? [Any] ?? []).enumerated() {
      guard case .success(.addText(let text)) = BoardOps.op(ghost) else {
        throw Unreadable(description: "ghost \(index) is not an add_text Larry could send")
      }
      ghosts.append(text)
    }
    for touch in json["touched"] as? [[String: Any]] ?? [] {
      guard let rev = JSONNumber(touch["rev"])?.intValue else { continue }
      touched.append(Touch(rev: rev, ids: touch["ids"] as? [String] ?? []))
    }
  }

  /// As it was read, so a replay's result is the next one's snapshot.
  public var json: [String: Any] {
    var strokes: [[String: Any]] = ink.map { ink in
      var out: [String: Any] = [
        "id": ink.id, "color": ink.color, "width": Double(ink.width), "tool": ink.tool,
        "points": ink.points.map { [Double($0.x), Double($0.y)] },
      ]
      if let t = ink.t { out["t"] = t }
      if ink.hidden { out["hidden"] = true }
      if let meta = ink.meta { out["meta"] = meta.object }
      return out
    }
    strokes += texts.map { text in
      var out: [String: Any] = [
        "kind": "text", "id": text.id, "text": text.text, "font": text.font.strokesFont, "x": Double(text.box.minX),
        "y": Double(text.box.minY), "w": Double(text.box.width), "h": Double(text.box.height), "color": text.color,
        "t": text.t,
      ]
      if let size = text.size { out["size"] = Double(size) }
      if let meta = text.meta { out["meta"] = meta.object }
      return out
    }
    var out: [String: Any] = ["board": board, "strokes": strokes]
    if let rev { out["rev"] = rev }
    if let pages { out["pages"] = pages }
    if !ghosts.isEmpty { out["ghosts"] = ghosts.map(\.wire) }
    if !touched.isEmpty { out["touched"] = touched.map { ["rev": $0.rev, "ids": $0.ids] as [String: Any] } }
    return out
  }

  // MARK: As a plan sees it

  /// The name a kept text's glyphs go by in a plan: never one Larry sends (`#` is not in a name).
  static func glyphName(_ id: String) -> String { "\(id)#glyphs" }

  /// The board as `BoardOps.plan` takes it: the ink, then one stroke for each kept text's glyphs, made at its time.
  public var planInput: (strokes: [BoardOps.Stroke], texts: [BoardText], metas: BoardStrokeMeta) {
    var metas = BoardStrokeMeta()
    var strokes = ink.map { ink in
      // No time: a time is how a text's glyphs are known, and plain ink is none of them.
      BoardOps.Stroke(
        ids: [ink.id], t: nil, bounds: ink.bounds, hidden: ink.hidden, points: ink.points, pen: ink.width)
    }
    for ink in ink { if let meta = ink.meta { metas.set(meta, for: ink.id) } }
    var kept: [BoardText] = []
    for text in texts {
      strokes.append(BoardOps.Stroke(ids: [Self.glyphName(text.id)], t: text.t, bounds: text.box))
      kept.append(
        BoardText(
          id: text.id, t: text.t, text: text.text, font: text.font, size: Double(text.size ?? text.box.height),
          color: text.color, glyphs: 1))
      if let meta = text.meta { metas.set(meta, for: text.id) }
    }
    return (strokes, kept, metas)
  }

  /// The pages the column has: as given, else enough for the ink.
  public var pageCount: Int {
    pages ?? BoardPages().pagesNeeded(inkMaxY: (ink.map(\.bounds) + texts.map(\.box)).map(\.maxY).max())
  }

  /// `#rrggbb` for a colour Larry named, or his purple.
  static func hex(_ color: UInt32?) -> String {
    String(format: "#%06x", color ?? WhiteboardTurn.larryColor)
  }
}

extension BoardOps.Text {
  /// As Larry sends it: an `add_text` op.
  public var wire: [String: Any] {
    var out: [String: Any] = [
      "op": "add_text", "id": id, "x": Double(x), "y": Double(y), "text": text, "font": font.rawValue,
      "size": Double(size),
    ]
    if let color { out["color"] = String(format: "#%06X", color) }
    if let lettering { out["lettering"] = lettering.rawValue }
    return out
  }

  /// The box its letters take on the board: as the host that draws it measured it when it says, else their outlines'
  /// where the system has the font, else an estimate from its size (a host without fonts, `just test-linux`).
  public var box: CGRect {
    if let measured { return CGRect(origin: CGPoint(x: x, y: y), size: measured) }
    let lines = WhiteboardTurn.lines(shape, frame: .zero, scale: 1)
    let drawn = WhiteboardMarkChoice.bounds(lines)
    if !drawn.isNull { return CGRect(x: x, y: y, width: max(drawn.maxX - x, 1), height: max(drawn.maxY - y, size)) }
    return CGRect(x: x, y: y, width: CGFloat(text.count) * size * 0.55, height: size * 1.25)
  }
}
