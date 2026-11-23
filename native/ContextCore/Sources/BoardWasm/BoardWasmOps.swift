//  Larry's ops for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version
//  7): the batch read by `BoardOps.batch` (its refusals, as the iPad names them) and planned by `BoardOps.plan` on the
//  web board, the plan given back by name so the Cockpit applies it to its own board. No board is kept: each call
//  carries the one it asks about. Only the export is WASI's; the answer builds everywhere.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebOps {
  static func number(_ any: Any?) -> CGFloat? { (any as? NSNumber).map { CGFloat($0.doubleValue) } }

  static func hex(_ color: UInt32?) -> Any {
    guard let color else { return NSNull() }
    let digits = String(color, radix: 16)
    return "#" + String(repeating: "0", count: max(0, 6 - digits.count)) + digits
  }

  static func color(_ any: Any?) -> UInt32? {
    guard let s = any as? String, s.count == 7, s.first == "#" else { return nil }
    return UInt32(s.dropFirst(), radix: 16)
  }

  /// One of Larry's text ghosts showing: `{"id", "x", "y", "text", "font", "size", "color"}`.
  static func ghost(_ any: Any) -> BoardOps.Text? {
    guard let g = any as? [String: Any], let id = g["id"] as? String, let x = number(g["x"]), let y = number(g["y"]),
      let text = g["text"] as? String
    else { return nil }
    return BoardOps.Text(
      id: id, x: x, y: y, text: text, font: (g["font"] as? String).flatMap(BoardOps.Font.init(rawValue:)) ?? .plain,
      size: number(g["size"]).flatMap { $0 > 0 ? $0 : nil } ?? 18, color: color(g["color"]))
  }

  static func text(_ t: BoardOps.Text) -> [String: Any] {
    ["id": t.id, "x": Double(t.x), "y": Double(t.y), "text": t.text, "font": t.font.rawValue, "size": Double(t.size),
     "color": hex(t.color)]
  }

  /// The batch as read: its refusal, label, base revision and the names its ops use (what an older look conflicts on).
  static func batchWire(_ batch: BoardOps.Batch) -> [String: Any] {
    [
      "refusal": batch.refusal as Any? ?? NSNull(), "label": batch.label, "board": batch.board as Any? ?? NSNull(),
      "base_rev": batch.baseRev as Any? ?? NSNull(), "ops": batch.ops.count,
      "names_used": BoardOps.namesUsed(batch.ops).sorted(),
    ]
  }

  /// `{"batch": the message's ops JSON, "key", "board"?}` → `{"batch": batchWire, "plan"?}`. `board`, when given, is
  /// `{"strokes": [ink], "boxes": [kept texts and cards], "metas": {name: notes}, "folds": {name: "h:<header>"},
  /// "ghosts": [text], "pages"}`: ink and boxes as `bw_outline_load` reads them, a box's name the one Larry knows it by.
  /// The plan names what it touches; nothing is placed by canvas index.
  static func plan(_ json: Any?) throws -> [String: Any] {
    guard let json = json as? [String: Any] else { throw WebOutlineUnreadable(description: "ops ask for an object") }
    guard let batch = BoardOps.batch(json["batch"], key: json["key"] as? String ?? "", source: "web") else {
      return ["batch": NSNull()]
    }
    var out: [String: Any] = ["batch": batchWire(batch)]
    guard batch.refusal == nil, let board = json["board"] as? [String: Any] else { return out }
    let ink = try (board["strokes"] as? [Any] ?? []).enumerated().map { try WebOutline.ink($1, $0) }
    let boxes = try (board["boxes"] as? [Any] ?? []).enumerated().map { try WebOutline.box($1, $0) }
    let strokes = ink + boxes
    var metas = BoardStrokeMeta()
    for (name, raw) in board["metas"] as? [String: Any] ?? [:] {
      if let meta = BoardMeta(raw) { metas.set(meta, for: name) }
    }
    let ghosts = (board["ghosts"] as? [Any] ?? []).compactMap(ghost)
    let plan = BoardOps.plan(
      batch.ops, strokes: strokes, metas: metas, folds: board["folds"] as? [String: String] ?? [:], ghosts: ghosts,
      pages: (board["pages"] as? NSNumber)?.intValue ?? 1)
    let name = { (i: Int) in strokes[i].ids[0] }
    out["plan"] = [
      "moves": Dictionary(
        plan.offsets.map { (name($0.key), [Double($0.value.dx), Double($0.value.dy)]) }, uniquingKeysWith: { a, _ in a }),
      "erase": plan.erase.sorted().map(name),
      "hidden": Dictionary(plan.hidden.map { (name($0.key), $0.value) }, uniquingKeysWith: { a, _ in a }),
      "added": plan.added.map { s -> [String: Any] in
        [
          "id": s.id, "points": s.points.map { [Double($0.x), Double($0.y)] }, "width": Double(s.width),
          "color": hex(s.color), "meta": s.meta?.object ?? NSNull(), "hidden": s.hidden,
        ]
      },
      "metas": plan.metas.mapValues(\.object), "forget": plan.forgetMetas.sorted(), "select": plan.select,
      "texts": plan.texts.map(text), "dismissed": plan.dismissed, "inked": plan.inked.map(text),
      "missing_ids": plan.missingIDs, "rooms": plan.rooms.map(\.wire), "moved": plan.moved,
      "pages_after": plan.pagesAfter, "connected": plan.connected, "rerouted": plan.rerouted,
      "loosened": plan.loosened,
    ] as [String: Any]
    return out
  }
}

#if os(WASI)
  /// Larry's batch read and planned (`WebOps.plan`), as a reply; `{"error"}` when it can't be read.
  @_expose(wasm, "bw_ops_plan")
  @_cdecl("bw_ops_plan")
  public func bwOpsPlan(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    do {
      return reply(json: try WebOps.plan(JSONSerialization.jsonObject(with: input(pointer, length))))
    } catch {
      return reply(json: ["error": "the ops could not be read: \(error)"])
    }
  }
#endif
