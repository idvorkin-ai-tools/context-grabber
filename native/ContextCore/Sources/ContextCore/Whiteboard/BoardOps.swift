//  Larry edits the board (spec 2026-11-16-whiteboard-board-ops-design.md, stories 814–819; plan
//  2026-11-16-whiteboard-board-ops-plan.md). A batch of changes arrives from a source (`BoardOpSource`: today Larry's
//  board replies, later his own rules inside the app); here, what a batch says, which strokes each change moves, how many
//  pages the board needs after, and when the Pencil lets it apply. The applier (`BoardOpApplier`) decides whether it
//  applies at all. PaperKit stays in the app. All in raw board points, origin the board's top-left: the space of the
//  `strokes` the app sends Larry, never a picture's `frame`.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardOps {
  /// The most changes one batch may hold.
  public static let maxOps = 50
  /// The furthest one change may move anything, either way, in board points.
  public static let maxShift: CGFloat = 4000

  /// Why a batch was refused, as Larry reads it in `op_result.reason`.
  public enum Reason {
    public static let stale = "stale"
    public static let tooManyOps = "too_many_ops"
    public static let dyOutOfRange = "dy_out_of_range"
    public static let dxOutOfRange = "dx_out_of_range"
    public static let unknownOp = "unknown_op"
    /// An op of a kind it knows with a field missing or out of reach.
    public static let badOp = "bad_op"
    /// No board, base revision or list.
    public static let badBatch = "bad_batch"
    /// The board is only looked at on this device (story 347).
    public static let lookOnly = "look_only"
    /// Held for the Pencil and replaced by a newer batch before it applied.
    public static let superseded = "superseded"
  }

  public enum Font: String, Codable, Sendable {
    case plain, hand
    /// The lettering a ghost draws it in.
    public var face: WhiteboardTurn.Face { self == .plain ? .print : .hand }
  }

  /// A line of Larry's text, as `add_text` asks for it.
  public struct Text: Equatable, Sendable {
    public var id: String
    /// The text's top-left.
    public var x: CGFloat
    public var y: CGFloat
    public var text: String
    public var font: Font
    /// Letter height in board points.
    public var size: CGFloat
    /// `0xRRGGBB`; nil is Larry's colour.
    public var color: UInt32?

    public init(
      id: String, x: CGFloat, y: CGFloat, text: String, font: Font = .plain, size: CGFloat = 18, color: UInt32? = nil
    ) {
      self.id = id
      self.x = x
      self.y = y
      self.text = text
      self.font = font
      self.size = size
      self.color = color
    }

    /// The mark its ghost draws, placed with a frame at the board's origin and a scale of 1.
    public var shape: WhiteboardTurn.Shape {
      WhiteboardTurn.Shape(
        kind: .text, points: [CGPoint(x: x, y: y)], text: text, size: size, color: color, face: font.face)
    }
  }

  public enum Op: Equatable, Sendable {
    /// Everything whose top is at or below `y` moves down by `dy`.
    case translateBelow(y: CGFloat, dy: CGFloat)
    /// The strokes (or kept texts) with these ids move.
    case translateIDs([String], dx: CGFloat, dy: CGFloat)
    /// A ghost of Larry's text.
    case addText(Text)
  }

  public struct Batch: Equatable, Sendable {
    /// What makes it the same batch when seen again: its message's id, or `label@base_rev` without one.
    public var key: String
    /// Who sent it, for the log: `web`, later `local`.
    public var source: String
    public var board: String?
    public var label: String
    public var baseRev: Int?
    public var ops: [Op]
    /// Set when the wire couldn't be taken: the batch is refused for this reason and nothing of it applies.
    public var refusal: String?

    public init(
      key: String, source: String, board: String?, label: String, baseRev: Int?, ops: [Op], refusal: String? = nil
    ) {
      self.key = key
      self.source = source
      self.board = board
      self.label = label
      self.baseRev = baseRev
      self.ops = ops
      self.refusal = refusal
    }
  }

  /// What came of a batch, for Larry's next turn (`op_result`).
  public struct Result: Equatable, Codable, Sendable {
    public var label: String
    public var ok: Bool
    /// The board's revision once it was handled.
    public var rev: Int
    public var reason: String?
    /// Ids a translate named that the board doesn't have; the rest of the batch applied.
    public var missingIDs: [String]?

    public init(label: String, ok: Bool, rev: Int, reason: String? = nil, missingIDs: [String]? = nil) {
      self.label = label
      self.ok = ok
      self.rev = rev
      self.reason = reason
      self.missingIDs = missingIDs
    }

    public var wire: [String: Any] {
      var out: [String: Any] = ["label": label, "ok": ok, "rev": rev]
      if let reason { out["reason"] = reason }
      if let missingIDs, !missingIDs.isEmpty { out["missing_ids"] = missingIDs }
      return out
    }
  }

  // MARK: The wire

  /// A message's `ops` as a batch; nil when it has none. `key` is the message's id.
  public static func batch(_ json: Any?, key: String, source: String) -> Batch? {
    guard let json = json as? [String: Any] else { return nil }
    let board = json["board"] as? String
    let baseRev = (json["base_rev"] as? NSNumber).flatMap { n -> Int? in
      let d = n.doubleValue
      return d.isFinite && d == d.rounded() ? Int(d) : nil
    }
    let label = json["label"] as? String ?? ""
    var batch = Batch(key: key, source: source, board: board, label: label, baseRev: baseRev, ops: [])
    guard board != nil, baseRev != nil, let list = json["list"] as? [Any] else {
      batch.refusal = Reason.badBatch
      return batch
    }
    guard list.count <= maxOps else {
      batch.refusal = Reason.tooManyOps
      return batch
    }
    for item in list {
      switch op(item) {
      case .success(let op): batch.ops.append(op)
      case .failure(let refusal):
        batch.refusal = refusal.reason
        batch.ops = []
        return batch
      }
    }
    return batch
  }

  struct Refusal: Error { let reason: String }

  static func op(_ any: Any) -> Swift.Result<Op, Refusal> {
    guard let json = any as? [String: Any], let kind = json["op"] as? String else {
      return .failure(Refusal(reason: Reason.badOp))
    }
    let place = { (key: String) in json[key].flatMap(WhiteboardTurn.number) }
    let shift = { (key: String) -> CGFloat? in
      (json[key] as? NSNumber).map { CGFloat($0.doubleValue) }
    }
    switch kind {
    case "translate":
      let dy = shift("dy")
      let dx = shift("dx")
      if let dy, !(dy.isFinite && abs(dy) <= maxShift) { return .failure(Refusal(reason: Reason.dyOutOfRange)) }
      if let dx, !(dx.isFinite && abs(dx) <= maxShift) { return .failure(Refusal(reason: Reason.dxOutOfRange)) }
      if let ids = json["ids"] {
        guard let ids = ids as? [String], dx != nil || dy != nil else { return .failure(Refusal(reason: Reason.badOp)) }
        return .success(.translateIDs(ids, dx: dx ?? 0, dy: dy ?? 0))
      }
      guard let y = place("below_y"), let dy else { return .failure(Refusal(reason: Reason.badOp)) }
      return .success(.translateBelow(y: y, dy: dy))
    case "add_text":
      let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard let id = json["id"] as? String, !id.isEmpty, let x = place("x"), let y = place("y"), !text.isEmpty else {
        return .failure(Refusal(reason: Reason.badOp))
      }
      let size = place("size").flatMap { $0 > 0 ? $0 : nil } ?? 18
      let font = (json["font"] as? String).flatMap(Font.init(rawValue:)) ?? .plain
      return .success(
        .addText(
          Text(id: id, x: x, y: y, text: text, font: font, size: size, color: WhiteboardTurn.hexColor(json["color"]))))
    default:
      return .failure(Refusal(reason: Reason.unknownOp))
    }
  }

  // MARK: What moves

  /// One stroke on the canvas as the plan sees it: the ids Larry knows it by (one per visible stretch) and when it was
  /// made, unix ms.
  public struct Stroke: Equatable, Sendable {
    public var ids: [String]
    public var t: Int64?
    public var bounds: CGRect

    public init(ids: [String], t: Int64?, bounds: CGRect) {
      self.ids = ids
      self.t = t
      self.bounds = bounds
    }
  }

  /// What moves as a whole: a stroke, or every glyph of a kept text.
  public struct Item: Equatable, Sendable {
    public var ids: Set<String>
    /// The strokes' places on the canvas.
    public var members: [Int]
    public var bounds: CGRect
  }

  /// The canvas's strokes as items: a kept text's glyphs (made at its time) are one item answering to its id too.
  public static func items(strokes: [Stroke], texts: [BoardText] = []) -> [Item] {
    let byTime = Dictionary(texts.map { ($0.t, $0.id) }, uniquingKeysWith: { _, new in new })
    var out: [Item] = []
    var textItem: [String: Int] = [:]
    for (index, stroke) in strokes.enumerated() {
      if let t = stroke.t, let text = byTime[t] {
        if let at = textItem[text] {
          out[at].ids.formUnion(stroke.ids)
          out[at].members.append(index)
          out[at].bounds = out[at].bounds.union(stroke.bounds)
          continue
        }
        textItem[text] = out.count
        out.append(Item(ids: Set(stroke.ids + [text]), members: [index], bounds: stroke.bounds))
      } else {
        out.append(Item(ids: Set(stroke.ids), members: [index], bounds: stroke.bounds))
      }
    }
    return out
  }

  public struct Plan: Equatable, Sendable {
    /// How far each stroke moves, by its place on the canvas; strokes that stay are absent.
    public var offsets: [Int: CGVector] = [:]
    /// Ghosts of Larry's text to show.
    public var texts: [Text] = []
    public var pagesBefore: Int
    public var pagesAfter: Int
    /// Items that moved.
    public var moved = 0
    public var missingIDs: [String] = []

    /// The board itself changes: something moves or a page is added. Text alone only shows ghosts.
    public var changesBoard: Bool { !offsets.isEmpty || pagesAfter != pagesBefore }
  }

  /// The batch's changes on `items`, in order, each seeing the board as the ones before it left it. `pages` is the
  /// column's page count now; it grows to hold the ink after, and the room a push opens below the last ink.
  public static func plan(_ ops: [Op], items: [Item], pages: Int, board: BoardPages = BoardPages()) -> Plan {
    var bounds = items.map(\.bounds)
    var shifts = [CGVector](repeating: .zero, count: items.count)
    var plan = Plan(pagesBefore: pages, pagesAfter: pages)
    var reach: CGFloat?
    func move(_ i: Int, _ dx: CGFloat, _ dy: CGFloat) {
      bounds[i] = bounds[i].offsetBy(dx: dx, dy: dy)
      shifts[i].dx += dx
      shifts[i].dy += dy
    }
    for op in ops {
      switch op {
      case .translateBelow(let y, let dy):
        for i in bounds.indices where bounds[i].minY >= y { move(i, 0, dy) }
        if dy > 0 { reach = max(reach ?? y + dy, y + dy) }
      case .translateIDs(let ids, let dx, let dy):
        var hit = Set<Int>()
        for id in ids {
          let found = items.indices.filter { items[$0].ids.contains(id) }
          if found.isEmpty { plan.missingIDs.append(id) }
          hit.formUnion(found)
        }
        for i in hit.sorted() { move(i, dx, dy) }
      case .addText(let text):
        plan.texts.removeAll { $0.id == text.id }
        plan.texts.append(text)
      }
    }
    for (i, shift) in shifts.enumerated() where shift.dx != 0 || shift.dy != 0 {
      plan.moved += 1
      for member in items[i].members { plan.offsets[member] = shift }
    }
    let inkMaxY = (bounds.map(\.maxY) + (reach.map { [$0] } ?? [])).max()
    plan.pagesAfter = board.pages(after: pages, inkMaxY: inkMaxY, redoWaiting: false)
    return plan
  }

  // MARK: The Pencil

  public enum Readiness: Equatable, Sendable {
    case now
    /// The Pencil lifted a moment ago: look again after this long.
    case after(Duration)
    /// The Pencil is down: look again when it lifts.
    case onLift
  }

  /// Whether a change may move ink now: never under a live pen, nor within `hold` of its lift (the board's pause).
  public static func readiness(
    penDown: Bool, liftedAt: ContinuousClock.Instant?, now: ContinuousClock.Instant,
    hold: Duration = WhiteboardPacer.pause
  ) -> Readiness {
    if penDown { return .onLift }
    guard let liftedAt else { return .now }
    let since = liftedAt.duration(to: now)
    return since >= hold ? .now : .after(hold - since)
  }

  /// One line for the session log about a batch: what it is, without its text.
  public static func logFields(_ batch: Batch) -> [String: Any] {
    var out: [String: Any] = [
      "label": batch.label, "source": batch.source, "key": batch.key, "ops": batch.ops.count,
      "base_rev": batch.baseRev as Any? ?? NSNull(),
    ]
    var kinds: [String: Int] = [:]
    for op in batch.ops {
      switch op {
      case .translateBelow: kinds["translate_below", default: 0] += 1
      case .translateIDs: kinds["translate_ids", default: 0] += 1
      case .addText: kinds["add_text", default: 0] += 1
      }
    }
    if !kinds.isEmpty { out["kinds"] = kinds }
    return out
  }
}
