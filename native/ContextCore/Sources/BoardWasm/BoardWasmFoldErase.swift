//  Erasing a fold whole, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The interface,
//  version 12): `BoardOutline.foldHits` (which shown folds an eraser's path takes, by their marker or their header's
//  words) and `eraseFolds` (the folds gone and the ink below closed up), over the outline `bw_outline_load` keeps, on a
//  copy. Only the export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebFoldErase {
  /// The folds a path takes (`path`, with `reach` and `onHeader`), or the folds of `headers` by name, and what erasing
  /// them all does, on a copy: `{"hits": [{"header", "byMarker", "headers", "names", "top"}], "erased": null | {"names",
  /// "headers", "moves": {name: dy}}}`.
  static func erase(
    _ outline: BoardOutline, path: [CGPoint]?, reach: CGFloat, onHeader: Bool, headers: [String]
  ) -> [String: Any] {
    let hits =
      path.map { outline.foldHits(along: $0, reach: reach, onHeader: onHeader) }
      ?? headers.compactMap { outline.foldHit($0) }
    let listed: [[String: Any]] = hits.map { hit in
      [
        "header": hit.header, "byMarker": hit.byMarker, "headers": hit.headers.sorted(), "names": hit.names.sorted(),
        "top": Double(hit.top),
      ]
    }
    var copy = outline
    guard copy.eraseFolds(hits) else { return ["hits": listed, "erased": NSNull()] }
    var moves: [String: Double] = [:]
    for (i, (was, now)) in zip(outline.strokes, copy.strokes).enumerated() where !copy.erased.contains(i) {
      let dy = now.bounds.minY - was.bounds.minY
      if dy != 0 { for name in now.ids { moves[name] = Double(dy) } }
    }
    let gone = Set(outline.headers.map(\.id)).subtracting(copy.headers.map(\.id))
    let erased: [String: Any] = [
      "names": copy.erased.sorted().flatMap { copy.strokes[$0].ids }, "headers": gone.sorted(), "moves": moves,
    ]
    return ["hits": listed, "erased": erased]
  }

  static func path(_ any: Any?) -> [CGPoint]? {
    guard let list = any as? [Any] else { return nil }
    return list.compactMap { pair -> CGPoint? in
      guard let pair = pair as? [Any], pair.count >= 2, let x = WebOutline.number(pair[0]),
        let y = WebOutline.number(pair[1])
      else { return nil }
      return CGPoint(x: x, y: y)
    }
  }
}

#if os(WASI)
  /// `{"path": [[x, y]], "reach"?, "onHeader"?}` or `{"headers": [id]}`: the folds taken and what erasing them does, as
  /// a reply; `{"error"}` with no outline, or with neither a path nor headers.
  @_expose(wasm, "bw_fold_erase")
  @_cdecl("bw_fold_erase")
  public func bwFoldErase(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any] else {
      return reply(json: ["error": "no path or headers"])
    }
    let path = WebFoldErase.path(json["path"])
    let headers = (json["headers"] as? [Any])?.compactMap { $0 as? String }
    guard path != nil || headers != nil else { return reply(json: ["error": "no path or headers"]) }
    return reply(
      json: WebFoldErase.erase(
        loaded, path: path, reach: WebOutline.number(json["reach"]) ?? BoardOutline.eraseReach,
        onHeader: json["onHeader"] as? Bool ?? false, headers: headers ?? []))
  }
#endif
