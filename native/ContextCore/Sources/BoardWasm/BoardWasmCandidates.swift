//  Lines that look like headers, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, version 9): `BoardOutline.candidates` over the outline `bw_outline_load` keeps, with the lines Igor
//  declined. Only the export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebCandidates {
  /// `{"candidates": [{"y", "top", "bottom", "left", "right", "why"}]}`: the lines of the outline that look like
  /// headers and aren't yet, top down, none on a row holding a `declined` stroke.
  static func candidates(
    _ outline: BoardOutline, texts: [BoardText], groups: [String: String], declined: Set<String> = []
  ) -> [String: Any] {
    let asked =
      declined.isEmpty
      ? outline
      : BoardOutline(
        strokes: outline.strokes, headers: outline.headers, texts: texts, groups: groups,
        declined: outline.declined.union(declined), mine: outline.mine)
    let found: [[String: Any]] = asked.candidates().map { c in
      [
        "y": Double(c.y), "top": Double(c.box.minY), "bottom": Double(c.box.maxY), "left": Double(c.box.minX),
        "right": Double(c.box.maxX), "why": c.why.rawValue,
      ]
    }
    return ["candidates": found]
  }
}

#if os(WASI)
  /// `{"declined"?: [name]}`: the loaded outline's lines that look like headers, as a reply.
  @_expose(wasm, "bw_candidates")
  @_cdecl("bw_candidates")
  public func bwCandidates(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    let data = input(pointer, length)
    let json: [String: Any]
    if data.isEmpty {
      json = [:]
    } else {
      guard let read = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return reply(json: ["error": "the request is not a JSON object"])
      }
      json = read
    }
    let declined = (json["declined"] as? [Any] ?? []).compactMap { $0 as? String }
    return reply(
      json: WebCandidates.candidates(
        loaded, texts: outlineTexts, groups: outlineGroups, declined: Set(declined)))
  }
#endif
