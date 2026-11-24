//  Opening a folded header, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, version 11): `BoardOutline.opening` over the outline `bw_outline_load` keeps, on a copy. What slides, what
//  shows again, and the ink written under the folded header that ends its section from now on (story 1231). Only the
//  export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebOpening {
  /// What opening header `id` does, on a copy: `{"opening": null}` when it is not folded, else `{"opening": {"top",
  /// "slide", "moves": {name: dy}, "shown": [name], "ends": [name] | null}}`, `ends` the header's as it now is.
  static func opening(_ outline: BoardOutline, _ id: String) -> [String: Any] {
    var copy = outline
    guard let opened = copy.opening(id) else { return ["opening": NSNull()] }
    var moves: [String: Double] = [:]
    var shown: [String] = []
    for (was, now) in zip(outline.strokes, copy.strokes) {
      let dy = now.bounds.minY - was.bounds.minY
      if dy != 0 { for name in now.ids { moves[name] = Double(dy) } }
      if was.hidden && !now.hidden { shown += now.ids }
    }
    let ends: Any = copy.header(id)?.ends.map { $0 as Any } ?? NSNull()
    return [
      "opening": [
        "top": Double(opened.top), "slide": Double(opened.slide), "moves": moves, "shown": shown, "ends": ends,
      ] as [String: Any]
    ]
  }
}

#if os(WASI)
  /// `{"id"}`: what opening that folded header would do, as a reply; `{"error"}` with no outline or no id.
  @_expose(wasm, "bw_opening")
  @_cdecl("bw_opening")
  public func bwOpening(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let id = json["id"] as? String
    else { return reply(json: ["error": "no header id"]) }
    return reply(json: WebOpening.opening(loaded, id))
  }
#endif
