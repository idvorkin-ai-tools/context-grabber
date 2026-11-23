//  Larry's ops for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version
//  7): the batch read by `BoardOps.batch` (its refusals, as the iPad names them) and planned by `BoardOps.plan` on the
//  web board, the plan given back by name so the Cockpit applies it to its own board. No board is kept: each call
//  carries the one it asks about. Only the export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebOps {
  static func hex(_ color: UInt32?) -> Any {
    guard let color else { return NSNull() }
    let digits = String(color, radix: 16)
    return "#" + String(repeating: "0", count: max(0, 6 - digits.count)) + digits
  }

  static func measurement(_ any: Any?) -> CGSize? {
    guard let wh = any as? [Any], wh.count == 2,
      let w = WebOutline.number(wh[0]), w.isFinite, w > 0,
      let h = WebOutline.number(wh[1]), h.isFinite, h > 0
    else { return nil }
    return CGSize(width: w, height: h)
  }

  /// One of Larry's text ghosts showing: `{"id", "x", "y", "text", "font", "size", "color", "measured"}`.
  static func ghost(_ any: Any) -> BoardOps.Text? {
    guard let g = any as? [String: Any], let id = g["id"] as? String, let x = WebOutline.number(g["x"]),
      let y = WebOutline.number(g["y"]), let text = g["text"] as? String
    else { return nil }
    var ghost = BoardOps.Text(
      id: id, x: x, y: y, text: text, font: (g["font"] as? String).flatMap(BoardOps.Font.init(rawValue:)) ?? .plain,
      size: WebOutline.number(g["size"]).flatMap { $0 > 0 ? $0 : nil } ?? 18,
      color: WhiteboardTurn.hexColor(g["color"]))
    ghost.measured = measurement(g["measured"])
    return ghost
  }

  static func text(_ t: BoardOps.Text) -> [String: Any] {
    [
      "id": t.id, "x": Double(t.x), "y": Double(t.y), "text": t.text, "font": t.font.rawValue, "size": Double(t.size),
      "color": hex(t.color),
    ]
  }

  static func overlayWire(_ change: BoardOverlays.Change) -> [String: Any] {
    switch change {
    case .set(let overlay):
      let rect = overlay.rect
      var wire: [String: Any] = [
        "op": "overlay", "id": overlay.id, "kind": overlay.kind.rawValue, "label": overlay.label,
        "rect": ["x": Double(rect.minX), "y": Double(rect.minY), "w": Double(rect.width), "h": Double(rect.height)],
      ]
      wire["style"] = overlay.style?.object
      wire["tap_event"] = overlay.tapEvent?.object
      return wire
    case .remove(let id):
      return ["op": "remove_overlay", "id": id]
    }
  }

  /// The batch as read: its refusal, label, base revision and the names its ops use (what an older look conflicts on).
  static func batchWire(_ batch: BoardOps.Batch) -> [String: Any] {
    [
      "refusal": batch.refusal as Any? ?? NSNull(), "label": batch.label, "board": batch.board as Any? ?? NSNull(),
      "base_rev": batch.baseRev as Any? ?? NSNull(), "ops": batch.ops.count,
      "names_used": BoardOps.namesUsed(batch.ops).sorted(),
    ]
  }

  /// `{"batch": the message's ops JSON, "board"?}` → `{"batch": batchWire, "plan"?}`. `board`, when given, is
  /// `{"strokes": [ink], "boxes": [kept texts and cards], "metas": {name: notes}, "folds": {name: "h:<header>"},
  /// "ghosts": [text], "measured": {op index: [width, height]}, "pages"}`: ink and boxes as `bw_outline_load` reads
  /// them, a box's name the one Larry knows it by.
  /// The plan names what it touches; nothing is placed by canvas index.
  static func plan(_ json: Any?) throws -> [String: Any] {
    guard let json = json as? [String: Any] else { throw WebOutlineUnreadable(description: "ops ask for an object") }
    guard let batch = BoardOps.batch(json["batch"], key: "", source: "web") else {
      return ["batch": NSNull()]
    }
    var out: [String: Any] = ["batch": batchWire(batch)]
    guard batch.refusal == nil, let board = json["board"] as? [String: Any] else { return out }
    let ink = try (board["strokes"] as? [Any] ?? []).enumerated().map { try WebOutline.ink($1, $0) }
    var boxes = try (board["boxes"] as? [Any] ?? []).enumerated().map { try WebOutline.box($1, $0) }
    let kept = boxes.enumerated().map { WebOutline.boxText($1, $0) }
    for i in boxes.indices { boxes[i].t = kept[i].t }
    let strokes = ink + boxes
    var metas = BoardStrokeMeta()
    for (name, raw) in board["metas"] as? [String: Any] ?? [:] {
      if let meta = BoardMeta(raw) { metas.set(meta, for: name) }
    }
    let measured = board["measured"] as? [String: Any] ?? [:]
    let ghosts = (board["ghosts"] as? [Any] ?? []).compactMap(ghost)
    let ops = batch.ops.enumerated().map { index, op -> BoardOps.Op in
      guard case .addText(var text) = op else { return op }
      text.measured = measurement(measured[String(index)])
      return .addText(text)
    }
    let plan = BoardOps.plan(
      ops, strokes: strokes, texts: kept, metas: metas, folds: board["folds"] as? [String: String] ?? [:],
      ghosts: ghosts,
      pages: JSONNumber(board["pages"])?.intValue ?? 1)
    let name = { (i: Int) in strokes[i].ids[0] }
    var selected = Set<String>()
    out["plan"] =
      [
        "moves": Dictionary(
          plan.offsets.map { (name($0.key), [Double($0.value.dx), Double($0.value.dy)]) },
          uniquingKeysWith: { a, _ in a }),
        "erase": plan.erase.sorted().map(name),
        "hidden": Dictionary(plan.hidden.map { (name($0.key), $0.value) }, uniquingKeysWith: { a, _ in a }),
        "added": plan.added.map { s -> [String: Any] in
          [
            "id": s.id, "points": s.points.map { [Double($0.x), Double($0.y)] }, "width": Double(s.width),
            "color": hex(s.color), "meta": s.meta?.object ?? NSNull(), "hidden": s.hidden,
          ]
        },
        "metas": plan.metas.mapValues(\.object), "forget": plan.forgetMetas.sorted(),
        "select": plan.select.filter { selected.insert($0).inserted }, "overlays": plan.overlays.map(overlayWire),
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
