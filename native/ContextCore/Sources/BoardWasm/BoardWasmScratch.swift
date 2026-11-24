//  Scratch-out and hold-to-shape for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, version 17): whether a fast zigzag scratches out the ink under it and what goes (`WhiteboardScratchOut`),
//  over the outline `bw_outline_load` keeps, and the clean line, rectangle or ellipse a stroke held still at its end
//  becomes (`BoardShapeSnap`). Only the exports are WASI's; the answers build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebScratch {
  static func points(_ any: Any?) -> [CGPoint]? {
    guard let list = any as? [Any] else { return nil }
    var out: [CGPoint] = []
    for entry in list {
      guard let pair = entry as? [Any], pair.count >= 2, let x = WebOutline.number(pair[0]),
        let y = WebOutline.number(pair[1])
      else { return nil }
      out.append(CGPoint(x: x, y: y))
    }
    return out
  }

  /// The ink a scratch-out can take: every stroke of the outline that shows, with its points and pen. Kept texts and
  /// cards are boxes, not ink, and a scratch-out never takes them.
  static func ink(_ outline: BoardOutline) -> [WhiteboardScratchOut.Ink] {
    outline.strokes.filter { !$0.hidden && !$0.points.isEmpty }.map {
      WhiteboardScratchOut.Ink(id: $0.ids[0], points: $0.points, width: $0.pen)
    }
  }

  /// `{"ok", "gone", "reversals", "speed", "why", "finds_nothing", "zigzag"}` for the zigzag `points` drawn in `ms` (nil: not
  /// known) over the outline's ink: what goes with it, or why it stays ink. `zigzag`: fast enough and in shape to be a
  /// scratch-out whatever is under it, as one over a fold's marker is (`WhiteboardScratchOut.isZigzag`).
  static func scratchOut(_ outline: BoardOutline, points: [CGPoint], ms: Double?) -> [String: Any] {
    let outcome = WhiteboardScratchOut.check(points, ms: ms, over: ink(outline))
    return [
      "ok": outcome.ok, "gone": outcome.gone, "reversals": outcome.reversals,
      "speed": outcome.speed as Any? ?? NSNull(), "why": outcome.why as Any? ?? NSNull(),
      "finds_nothing": outcome.findsNothing, "zigzag": WhiteboardScratchOut.isZigzag(points, ms: ms),
    ]
  }

  /// `{"shape": {"kind", "name", "points", "error"} | null, "held": bool | null}`: the clean shape `points` nearly is,
  /// and, given each point's time and the lift's (seconds), whether the Pencil was held still at the end long enough
  /// to ask for it.
  static func snap(_ points: [CGPoint], times: [Double]?, lifted: Double?) -> [String: Any] {
    var held: Any = NSNull()
    if let times, let lifted, times.count == points.count, let last = points.last {
      var hold = BoardShapeSnap.Hold()
      for (point, time) in zip(points, times) { hold.moved(to: point, at: time) }
      held = hold.held(liftedAt: last, time: lifted)
    }
    let shape: Any =
      BoardShapeSnap.clean(points).map { shape -> [String: Any] in
        [
          "kind": shape.kind.rawValue, "name": BoardShapeSnap.name(shape.kind),
          "points": shape.points.map { [Double($0.x), Double($0.y)] }, "error": shape.error,
        ]
      } ?? NSNull()
    return ["shape": shape, "held": held]
  }
}

#if os(WASI)
  /// `{"points": [[x, y]], "ms"?}`: what a zigzag scratches out of the loaded outline, as a reply.
  @_expose(wasm, "bw_scratch_out")
  @_cdecl("bw_scratch_out")
  public func bwScratchOut(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let points = WebScratch.points(json["points"])
    else { return reply(json: ["error": "no points"]) }
    let ms = JSONNumber(json["ms"])?.doubleValue
    return reply(json: WebScratch.scratchOut(loaded, points: points, ms: ms))
  }

  /// `{"points": [[x, y]], "times"?: [s], "lifted"?}`: the clean shape a stroke snaps to, and whether it was held, as a
  /// reply. No board is needed.
  @_expose(wasm, "bw_shape_snap")
  @_cdecl("bw_shape_snap")
  public func bwShapeSnap(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let points = WebScratch.points(json["points"])
    else { return reply(json: ["error": "no points"]) }
    let times = (json["times"] as? [Any])?.compactMap { JSONNumber($0)?.doubleValue }
    return reply(json: WebScratch.snap(points, times: times, lifted: JSONNumber(json["lifted"])?.doubleValue))
  }
#endif
