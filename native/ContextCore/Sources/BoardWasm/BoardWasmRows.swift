//  What moves whole and the rows it makes, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md,
//  The interface, versions 10 and 13): the outline's units as the app's outline takes them (`BoardOps.items` with its
//  folds, what shows), each with its edges as the host sent them, and the rows those edges make, over the outline
//  `bw_outline_load` keeps. Only the export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Each stroke's and box's edges as the host sent them, `[left, top, right, bottom]` in 64 bits: a stroke's points
/// widened by half its pen, a box's own numbers. On wasm32 the rules' geometry is 32-bit, so the edges the web board
/// compares exactly come from here, never from the rules' boxes.
enum WebEdges {
  static func of(json any: Any) -> [String: [Double]] {
    guard let json = any as? [String: Any] else { return [:] }
    var out: [String: [Double]] = [:]
    for entry in (json["strokes"] as? [Any] ?? []).compactMap({ $0 as? [String: Any] }) {
      guard let id = entry["id"] as? String else { continue }
      let points = (entry["points"] as? [Any] ?? []).compactMap { pair -> (Double, Double)? in
        guard let pair = pair as? [Any], pair.count >= 2, let x = JSONNumber(pair[0])?.doubleValue,
          let y = JSONNumber(pair[1])?.doubleValue
        else { return nil }
        return (x, y)
      }
      guard let first = points.first else { continue }
      let half = (JSONNumber(entry["width"])?.doubleValue ?? 3) / 2
      var (l, t, r, b) = (first.0, first.1, first.0, first.1)
      for (x, y) in points.dropFirst() {
        l = min(l, x)
        r = max(r, x)
        t = min(t, y)
        b = max(b, y)
      }
      out[id] = [l - half, t - half, r + half, b + half]
    }
    for entry in (json["boxes"] as? [Any] ?? []).compactMap({ $0 as? [String: Any] }) {
      guard let id = entry["id"] as? String, let box = entry["box"] as? [Any], box.count == 4 else { continue }
      let edges = box.compactMap { JSONNumber($0)?.doubleValue }
      if edges.count == 4 { out[id] = edges }
    }
    return out
  }
}

enum WebRows {
  /// `{"units": [{"key", "names", "strokeIds", "objectIds", "object", "tag", "header", "box"}], "rows": [{"top",
  /// "bottom"}]}`: each thing that shows and moves whole, in board order, and the rows its edges make, top down.
  /// `names` are its strokes' and boxes' names (a folded header's with all it hides), split into ink (`strokeIds`) and
  /// the host's boxes and its group (`objectIds`); `object` the text, card or group that makes it one; `key` `h:<header>`,
  /// `o:<object>` or `s:<stroke>`; `box` what shows of it, `[left, top, right, bottom]`, from `edges` exactly.
  static func rows(
    _ outline: BoardOutline, texts: [BoardText], groups: [String: String], edges: [String: [Double]] = [:]
  ) -> [String: Any] {
    let units = BoardOps.items(strokes: outline.strokes, texts: texts, groups: groups, folds: outline.tags)
      .filter { !$0.hidden }
    var spans: [(top: Double, bottom: Double)] = []
    let out: [[String: Any]] = units.map { unit in
      let header = unit.tag.flatMap { $0.hasPrefix("h:") ? String($0.dropFirst(2)) : nil }
      let members = unit.members.map { outline.strokes[$0] }
      let names = members.flatMap(\.ids)
      let strokeIds = members.filter { !$0.points.isEmpty }.flatMap(\.ids)
      var objectIds = members.filter { $0.points.isEmpty }.flatMap(\.ids)
      let object = header == nil ? unit.tag : nil
      if let object, !objectIds.contains(object) { objectIds.append(object) }
      let key = header.map { "h:" + $0 } ?? object.map { "o:" + $0 } ?? "s:" + (names.first ?? "")
      // What shows of it, as the rules take it: its shown members, all of them when none shows.
      let shown = members.contains { !$0.hidden } ? members.filter { !$0.hidden } : members
      let box =
        shown.reduce(nil as [Double]?) { box, stroke in
          let b = stroke.bounds
          let e = edges[stroke.ids[0]] ?? [Double(b.minX), Double(b.minY), Double(b.maxX), Double(b.maxY)]
          guard let box else { return e }
          return [min(box[0], e[0]), min(box[1], e[1]), max(box[2], e[2]), max(box[3], e[3])]
        } ?? []
      if box.count == 4 { spans.append((box[1], box[3])) }
      return [
        "key": key, "names": names, "strokeIds": strokeIds, "objectIds": objectIds,
        "object": object.map { $0 as Any } ?? NSNull(), "tag": unit.tag.map { $0 as Any } ?? NSNull(),
        "header": header.map { $0 as Any } ?? NSNull(), "box": box,
      ]
    }
    // `BoardRoom.rows` over the exact edges: overlapping spans merged, top down.
    var rows: [(top: Double, bottom: Double)] = []
    for span in spans.sorted(by: { $0.top < $1.top }) {
      if let last = rows.last, span.top <= last.bottom {
        rows[rows.count - 1].bottom = max(last.bottom, span.bottom)
      } else {
        rows.append(span)
      }
    }
    return ["units": out, "rows": rows.map { ["top": $0.top, "bottom": $0.bottom] }]
  }
}

#if os(WASI)
  /// What moves whole on the loaded outline and the rows it makes, as a reply; `{"error"}` with no outline.
  @_expose(wasm, "bw_rows")
  @_cdecl("bw_rows")
  public func bwRows() -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebRows.rows(loaded, texts: outlineTexts, groups: outlineGroups, edges: outlineEdges))
  }
#endif
