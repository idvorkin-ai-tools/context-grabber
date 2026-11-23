//  What moves whole and the rows it makes, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md,
//  The interface, version 10): the outline's units as the app's outline takes them (`BoardOps.items` with its folds,
//  what shows) and `BoardRoom.rows` over their boxes, over the outline `bw_outline_load` keeps. Only the export is
//  WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebRows {
  /// `{"units": [{"names", "tag", "header", "box"}], "rows": [{"top", "bottom"}]}`: each thing that shows and moves
  /// whole, in board order, by its strokes' and boxes' names (a folded header's with all it hides), its text, group or
  /// header (`tag`, null for a lone stroke; `header` its header's id), and its box, what shows of it; then the rows its
  /// boxes make, top down, every height between them a clear line.
  static func rows(_ outline: BoardOutline, texts: [BoardText], groups: [String: String]) -> [String: Any] {
    let units = BoardOps.items(strokes: outline.strokes, texts: texts, groups: groups, folds: outline.tags)
      .filter { !$0.hidden }
    let out: [[String: Any]] = units.map { unit in
      let b = unit.bounds
      let header = unit.tag.flatMap { $0.hasPrefix("h:") ? String($0.dropFirst(2)) : nil }
      return [
        "names": unit.members.flatMap { outline.strokes[$0].ids }, "tag": unit.tag.map { $0 as Any } ?? NSNull(),
        "header": header.map { $0 as Any } ?? NSNull(),
        "box": [Double(b.minX), Double(b.minY), Double(b.maxX), Double(b.maxY)],
      ]
    }
    let rows: [[String: Any]] = BoardRoom.rows(units.map(\.bounds)).map {
      ["top": Double($0.lowerBound), "bottom": Double($0.upperBound)]
    }
    return ["units": out, "rows": rows]
  }
}

#if os(WASI)
  /// What moves whole on the loaded outline and the rows it makes, as a reply; `{"error"}` with no outline.
  @_expose(wasm, "bw_rows")
  @_cdecl("bw_rows")
  public func bwRows() -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebRows.rows(loaded, texts: outlineTexts, groups: outlineGroups))
  }
#endif
