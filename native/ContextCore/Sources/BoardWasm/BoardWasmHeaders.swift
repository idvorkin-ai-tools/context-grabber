//  Headers written in ink, Fold all and Collapse to a level, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 4): `BoardOutline.inkHeader`, `foldAll` and
//  `collapse(to:)` over the outline `bw_outline_load` keeps, each on a copy (the loaded outline stays as it was). Only
//  the exports are WASI's; the answers build everywhere.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebHeaders {
  static func header(_ header: BoardHeader) -> Any {
    (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(header))) ?? NSNull()
  }

  /// What the stroke named `name`, just drawn, does for headers (`BoardOutline.inkHeader`), the new header named `id`:
  /// `{"ink": null}`, or `{"ink": {"kind", "header", "y", "mark", "names"}, "after": the header as it now is}`.
  static func ink(_ outline: BoardOutline, name: String, id: String) -> [String: Any] {
    var copy = outline
    guard let newest = copy.strokes.firstIndex(where: { $0.ids.contains(name) }),
      let made = copy.inkHeader(newest: newest, id: id)
    else { return ["ink": NSNull()] }
    var out: [String: Any] = ["kind": made.kind, "header": made.header]
    switch made {
    case .underline(_, let y, let mark), .hash(_, let y, let mark):
      out["y"] = Double(y)
      out["mark"] = mark
    case .deeper(_, let level, let y, let mark):
      out["y"] = Double(y)
      out["mark"] = mark
      out["level"] = level
    case .grew(_, let names):
      out["names"] = names
    }
    return ["ink": out, "after": copy.header(made.header).map(header) ?? NSNull()]
  }

  /// Fold all (`to` nil, `BoardOutline.foldAll`) or Collapse to level `to` (`collapse(to:)`), on a copy: each fold
  /// as it was made, in order, `{"open": whether every fold opened first, "levels", "folds": [{"id", "ids", "own",
  /// "shift", "lines", "bottom"}]}`.
  static func plan(_ outline: BoardOutline, to level: Int?) -> [String: Any] {
    var copy = outline
    let levels = copy.levels()
    if level != nil { copy.unfoldAll() }
    // Both fold from the lowest header up, in the order the board had when they began; each fold keeps what it did
    // as it did it, so the host makes the same folds in the same order.
    let order = copy.headers.compactMap { h in copy.box(h).map { (h.id, $0.minY) } }.sorted { $0.1 > $1.1 }.map(\.0)
    let before = Set(copy.headers.filter { copy.isFolded($0) }.map(\.id))
    if let level { copy.collapse(to: level) } else { copy.foldAll() }
    let folds: [[String: Any]] = order.compactMap { id in
      guard !before.contains(id), let f = copy.header(id)?.fold else { return nil }
      return [
        "id": id, "ids": f.ids, "own": f.own, "shift": Double(f.shift), "lines": f.lines, "bottom": Double(f.bottom),
      ]
    }
    return ["open": level != nil, "levels": levels, "folds": folds]
  }
}

#if os(WASI)
  /// `{"name", "id"}`: what the stroke `name`, just drawn and already in the outline, does for headers, as a reply.
  @_expose(wasm, "bw_ink_header")
  @_cdecl("bw_ink_header")
  public func bwInkHeader(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let name = json["name"] as? String, let id = json["id"] as? String
    else { return reply(json: ["error": "no stroke name and header id"]) }
    return reply(json: WebHeaders.ink(loaded, name: name, id: id))
  }

  /// `{}` for Fold all, `{"to": n}` for Collapse to level n: the folds it makes, in order, as a reply.
  @_expose(wasm, "bw_fold_plan")
  @_cdecl("bw_fold_plan")
  public func bwFoldPlan(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    let json = (try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any]) ?? [:]
    return reply(json: WebHeaders.plan(loaded, to: json["to"] as? Int))
  }
#endif
