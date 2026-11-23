//  The room a reply of Larry's opens when it is kept over ink Igor wrote after its picture, for the Cockpit's ink board
//  (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 8): `BoardRoom.late` over the outline
//  `bw_outline_load` keeps. Only the export is WASI's; the answer builds everywhere.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebKeep {
  /// `{"push": {"cut", "dy"} | null, "covered"}` for marks at `marks` kept over the outline, its picture taken at
  /// `seen` (unix ms).
  static func late(
    _ outline: BoardOutline, texts: [BoardText], groups: [String: String], marks: [CGRect], seen: Int64
  ) -> [String: Any] {
    let late = BoardRoom.late(
      marks, seen: seen, strokes: outline.strokes, texts: texts, groups: groups, folds: outline.tags)
    let push: Any = late.push.map { ["cut": Double($0.cut), "dy": Double($0.dy)] } ?? NSNull()
    return ["push": push, "covered": late.covered]
  }

  /// `{"sits", "y", "cut", "dy"}`: where a text of Larry's at `box` lands among what shows of the outline
  /// (`BoardRoom.text`), whether it sits on any of it, and the clear line and push of the room it opens (`dy` 0 for
  /// none; `cut` the clear line nearest its top whenever it sits).
  static func text(_ outline: BoardOutline, texts: [BoardText], groups: [String: String], box: CGRect) -> [String: Any]
  {
    let shown = BoardOps.items(strokes: outline.strokes, texts: texts, groups: groups, folds: outline.tags)
      .filter { !$0.hidden }.map(\.bounds)
    let land = BoardRoom.text(box, among: shown)
    // as BoardRoom.text tells it: some of what shows overlaps it by some area
    let sits = shown.contains { other in
      let overlap = other.intersection(box)
      return !overlap.isNull && overlap.width > 0 && overlap.height > 0
    }
    return [
      "sits": sits, "y": Double(land.y), "cut": Double(land.push?.cut ?? BoardRoom.cut(shown, at: box.minY)),
      "dy": Double(land.push?.dy ?? 0),
    ]
  }
}

#if os(WASI)
  /// `{"box": [left, top, right, bottom]}`: where a text of Larry's there lands and the room it opens, as a reply.
  @_expose(wasm, "bw_text_room")
  @_cdecl("bw_text_room")
  public func bwTextRoom(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let box = WebConnectors.box(json["box"])
    else { return reply(json: ["error": "no box"]) }
    return reply(json: WebKeep.text(loaded, texts: outlineTexts, groups: outlineGroups, box: box))
  }

  /// `{"marks": [[left, top, right, bottom]], "seen"}`: the room the marks open, kept now, as a reply.
  @_expose(wasm, "bw_late")
  @_cdecl("bw_late")
  public func bwLate(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let seen = (json["seen"] as? NSNumber)?.int64Value
    else { return reply(json: ["error": "no marks and seen"]) }
    let marks = (json["marks"] as? [Any] ?? []).compactMap(WebConnectors.box)
    return reply(
      json: WebKeep.late(loaded, texts: outlineTexts, groups: outlineGroups, marks: marks, seen: seen))
  }
#endif
