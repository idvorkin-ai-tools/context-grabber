//  The room a reply of Larry's opens when it is kept over ink Igor wrote after its picture, for the Cockpit's ink board
//  (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 7): `BoardRoom.late` over the outline
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
}

#if os(WASI)
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
