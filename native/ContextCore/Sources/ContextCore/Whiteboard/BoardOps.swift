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
    /// More strokes in one op than `maxNewStrokes`, or a stroke with more points than the Cockpit takes.
    public static let tooManyStrokes = "too_many_strokes"
    public static let tooManyPoints = "too_many_points"
  }

  /// The most strokes one `add_strokes` or `replace` may draw.
  public static let maxNewStrokes = 500

  /// A name the Cockpit's strokes endpoint takes (`[A-Za-z0-9_-]{1,64}`, whiteboard_strokes.py): anything Larry names
  /// goes back to it in the strokes.
  public static func isName(_ id: String) -> Bool {
    (1...64).contains(id.utf8.count)
      && id.utf8.allSatisfy {
        ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95
      }
  }

  /// A stroke Larry draws, as `add_strokes` and `replace` give it.
  public struct NewStroke: Equatable, Sendable {
    public var id: String
    public var points: [CGPoint]
    /// In board points, within what a kept mark draws at (`WhiteboardTurn.thinnestPen`...`widestPen`).
    public var width: CGFloat
    /// `0xRRGGBB`; nil is Larry's colour.
    public var color: UInt32?
    public var meta: BoardMeta?
    public var hidden = false

    public init(
      id: String, points: [CGPoint], width: CGFloat = WhiteboardTurn.defaultPen, color: UInt32? = nil,
      meta: BoardMeta? = nil, hidden: Bool = false
    ) {
      self.id = id
      self.points = points
      self.width = width
      self.color = color
      self.meta = meta
      self.hidden = hidden
    }

    public var bounds: CGRect {
      guard let first = points.first else { return .null }
      return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
  }

  public enum Font: String, Codable, Sendable {
    case plain, hand
    /// The lettering a ghost draws it in.
    public var face: WhiteboardTurn.Face { self == .plain ? .print : .hand }
    /// As the Cockpit's strokes endpoint names it: `print` or `hand` (whiteboard_strokes.py).
    public var strokesFont: String { face.rawValue }
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
    /// Ink of Larry's, straight onto the board (story 840).
    case addStrokes([NewStroke])
    /// These strokes, texts or groups erased (story 841).
    case delete([String])
    /// Larry's notes on these strokes, kept as written; only `group` is read (story 842).
    case setMeta([String], BoardMeta)
    /// A delete and an add in one (story 841).
    case replace([String], with: [NewStroke])
    /// One of Larry's controls laid on the board, replacing one with its id (story 845).
    case overlay(BoardOverlay)
    case removeOverlay(String)
    /// These strokes hidden or shown again, as a fold (story 847).
    case setHidden([String], Bool)
    /// These strokes selected, as if lassoed (story 848).
    case select([String])
    /// An arrow joining two things, that follows them (stories 913, 914).
    case connector(NewConnector)
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
      guard let id = json["id"] as? String, isName(id), let x = place("x"), let y = place("y"), !text.isEmpty else {
        return .failure(Refusal(reason: Reason.badOp))
      }
      let size = place("size").flatMap { $0 > 0 ? $0 : nil } ?? 18
      let font = (json["font"] as? String).flatMap(Font.init(rawValue:)) ?? .plain
      return .success(
        .addText(
          Text(id: id, x: x, y: y, text: text, font: font, size: size, color: WhiteboardTurn.hexColor(json["color"]))))
    case "add_strokes":
      return newStrokes(json["strokes"]).map { .addStrokes($0) }
    case "delete":
      guard let ids = names(json["ids"]) else { return .failure(Refusal(reason: Reason.badOp)) }
      return .success(.delete(ids))
    case "set_meta":
      guard let ids = names(json["ids"]), let meta = BoardMeta(json["meta"]) else {
        return .failure(Refusal(reason: Reason.badOp))
      }
      return .success(.setMeta(ids, meta))
    case "replace":
      guard let ids = names(json["ids"]) else { return .failure(Refusal(reason: Reason.badOp)) }
      return newStrokes(json["strokes"]).map { .replace(ids, with: $0) }
    case "overlay":
      guard let overlay = BoardOverlay(json) else { return .failure(Refusal(reason: Reason.badOp)) }
      return .success(.overlay(overlay))
    case "remove_overlay":
      guard let id = json["id"] as? String, !id.isEmpty else { return .failure(Refusal(reason: Reason.badOp)) }
      return .success(.removeOverlay(id))
    case "set_hidden":
      guard let ids = names(json["ids"]), let hidden = json["hidden"] as? Bool else {
        return .failure(Refusal(reason: Reason.badOp))
      }
      return .success(.setHidden(ids, hidden))
    case "select":
      guard let ids = names(json["ids"]) else { return .failure(Refusal(reason: Reason.badOp)) }
      return .success(.select(ids))
    case "connector":
      return connector(json)
    default:
      return .failure(Refusal(reason: Reason.unknownOp))
    }
  }

  /// A list of names; nil for anything else.
  static func names(_ any: Any?) -> [String]? {
    guard let ids = any as? [String] else { return nil }
    return ids
  }

  static func newStrokes(_ any: Any?) -> Swift.Result<[NewStroke], Refusal> {
    guard let list = any as? [Any] else { return .failure(Refusal(reason: Reason.badOp)) }
    guard list.count <= maxNewStrokes else { return .failure(Refusal(reason: Reason.tooManyStrokes)) }
    var out: [NewStroke] = []
    for item in list {
      guard let json = item as? [String: Any], let id = json["id"] as? String, isName(id),
        let raw = json["points"] as? [Any], !raw.isEmpty
      else { return .failure(Refusal(reason: Reason.badOp)) }
      guard raw.count <= WhiteboardStrokes.maxPoints else { return .failure(Refusal(reason: Reason.tooManyPoints)) }
      var points: [CGPoint] = []
      for pair in raw {
        guard let pair = pair as? [Any], pair.count == 2, let x = WhiteboardTurn.number(pair[0]),
          let y = WhiteboardTurn.number(pair[1])
        else { return .failure(Refusal(reason: Reason.badOp)) }
        points.append(CGPoint(x: x, y: y))
      }
      let width = (json["width"] as? NSNumber).map { CGFloat($0.doubleValue) }.flatMap { $0.isFinite ? $0 : nil }
      var meta: BoardMeta?
      if let raw = json["meta"] {
        guard let parsed = BoardMeta(raw) else { return .failure(Refusal(reason: Reason.badOp)) }
        meta = parsed
      }
      out.append(
        NewStroke(
          id: id, points: points,
          width: min(WhiteboardTurn.widestPen, max(WhiteboardTurn.thinnestPen, width ?? WhiteboardTurn.defaultPen)),
          color: WhiteboardTurn.hexColor(json["color"]), meta: meta))
    }
    return .success(out)
  }

  // MARK: The Pencil

  public enum Readiness: Equatable, Sendable {
    case now
    /// The Pencil lifted a moment ago: look again after this long.
    case after(Duration)
    /// The Pencil is down: look again when it lifts.
    case onLift
  }

  /// How long after the Pencil lifts a change waits before it moves ink: half a second, the board's old fixed pause.
  public static let hold: Duration = .milliseconds(500)

  /// Whether a change may move ink now: never under a live pen, nor within `hold` of its lift.
  public static func readiness(
    penDown: Bool, liftedAt: ContinuousClock.Instant?, now: ContinuousClock.Instant,
    hold: Duration = BoardOps.hold
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
      case .addStrokes: kinds["add_strokes", default: 0] += 1
      case .delete: kinds["delete", default: 0] += 1
      case .setMeta: kinds["set_meta", default: 0] += 1
      case .replace: kinds["replace", default: 0] += 1
      case .overlay: kinds["overlay", default: 0] += 1
      case .removeOverlay: kinds["remove_overlay", default: 0] += 1
      case .setHidden: kinds["set_hidden", default: 0] += 1
      case .select: kinds["select", default: 0] += 1
      case .connector: kinds["connector", default: 0] += 1
      }
    }
    if !kinds.isEmpty { out["kinds"] = kinds }
    return out
  }
}
