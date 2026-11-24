//  Larry's unkept marks hold to the ink they answer and fade when written over, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 19): `BoardMarkHolds` over the outline
//  `bw_outline_load` keeps. The host keeps each mark's anchor, chosen once when the mark lands, and sends it back with
//  every question; the module keeps nothing of the marks. Only the exports are WASI's; the answers build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebMarks {
  /// A mark where it landed: `{"id", "lines": [[[x, y]]], "pen"?, "label"?}`.
  static func mark(_ any: Any?) -> BoardMark? {
    guard let entry = any as? [String: Any], let id = entry["id"] as? String, let list = entry["lines"] as? [Any]
    else { return nil }
    var lines: [[CGPoint]] = []
    for line in list {
      guard let points = WebScratch.points(line) else { return nil }
      lines.append(points)
    }
    return BoardMark(
      id: id, lines: lines, pen: WebOutline.number(entry["pen"]) ?? 2, label: entry["label"] as? Bool ?? false)
  }

  /// An anchor as `anchor` gave it: `{"strokes": [{"name", "x", "y"}], "gap"?, "written_by"?}`.
  static func anchor(_ any: Any?) -> BoardMarkAnchor? {
    guard let entry = any as? [String: Any], let list = entry["strokes"] as? [Any] else { return nil }
    var held: [BoardMarkAnchor.Held] = []
    for item in list {
      guard let stroke = item as? [String: Any], let name = stroke["name"] as? String,
        let x = JSONNumber(stroke["x"])?.doubleValue, let y = JSONNumber(stroke["y"])?.doubleValue
      else { return nil }
      held.append(BoardMarkAnchor.Held(name: name, x: x, y: y))
    }
    let writtenBy = (entry["written_by"] as? [Any] ?? []).compactMap { $0 as? String }
    return BoardMarkAnchor(strokes: held, gap: JSONNumber(entry["gap"])?.doubleValue ?? 0, writtenBy: writtenBy)
  }

  static func wire(_ anchor: BoardMarkAnchor) -> [String: Any] {
    [
      "strokes": anchor.strokes.map { ["name": $0.name, "x": $0.x, "y": $0.y] as [String: Any] }, "gap": anchor.gap,
      "written_by": anchor.writtenBy,
    ]
  }

  static func wire(_ place: BoardMarkHolds.Place) -> [String: Any] {
    [
      "dx": Double(place.dx), "dy": Double(place.dy), "hidden": place.hidden?.rawValue as Any? ?? NSNull(),
      "faded": place.faded, "drops": place.drops?.rawValue as Any? ?? NSNull(),
    ]
  }

  /// `[{"mark": {...}, "anchor"?: {...}}]` or `[{"id", "anchor"}]`: each mark (when given) and its anchor, by id.
  static func held(_ any: Any?, needLines: Bool) -> [(mark: BoardMark, anchor: BoardMarkAnchor?)]? {
    guard let list = any as? [Any] else { return nil }
    var out: [(BoardMark, BoardMarkAnchor?)] = []
    for item in list {
      guard let entry = item as? [String: Any] else { return nil }
      let anchor = entry["anchor"].flatMap { Self.anchor($0) }
      if entry["anchor"] != nil, anchor == nil { return nil }
      if let mark = Self.mark(entry["mark"]) {
        out.append((mark, anchor))
      } else if !needLines, let id = entry["id"] as? String {
        out.append((BoardMark(id: id, lines: [], pen: 0, label: false), anchor))
      } else {
        return nil
      }
    }
    return out
  }

  /// The outline's ink as the rule reads it: what shows, its groups and what each fold hides.
  static func ink(_ outline: BoardOutline, texts: [BoardText], groups: [String: String]) -> BoardMarkHolds.Ink {
    BoardMarkHolds.Ink(strokes: outline.strokes, texts: texts, groups: groups, folds: outline.tags)
  }

  /// The anchor a mark takes, landing on the outline as it is now (`BoardMarkHolds.anchor`).
  static func anchor(
    _ mark: BoardMark, outline: BoardOutline, texts: [BoardText], groups: [String: String]
  ) -> [String: Any] {
    ["anchor": wire(BoardMarkHolds.anchor(mark, on: ink(outline, texts: texts, groups: groups)))]
  }

  /// Where each mark shows on the outline as it is now (`BoardMarkHolds.place`), by id; a mark with no anchor holds
  /// to nothing and stays where it landed.
  static func places(_ marks: [(mark: BoardMark, anchor: BoardMarkAnchor?)], outline: BoardOutline) -> [String: Any]
  {
    var out: [String: Any] = [:]
    for (mark, anchor) in marks {
      out[mark.id] = wire(BoardMarkHolds.place(anchor ?? BoardMarkAnchor(strokes: []), on: outline.strokes))
    }
    return ["places": out]
  }

  /// Igor wrote `stroke` (already on the outline or not): each shown mark it writes over remembers it
  /// (`BoardMarkHolds.wrote`). The changed anchors by id, and each mark written over with the share of the stroke on it.
  static func wrote(
    _ stroke: BoardOps.Stroke, marks: [(mark: BoardMark, anchor: BoardMarkAnchor?)], outline: BoardOutline
  ) -> [String: Any] {
    var anchors: [String: BoardMarkAnchor] = [:]
    for (mark, anchor) in marks { anchors[mark.id] = anchor }
    let before = anchors
    let over = BoardMarkHolds.wrote(stroke, marks: marks.map(\.mark), anchors: &anchors, strokes: outline.strokes)
    var changed: [String: Any] = [:]
    for (id, anchor) in anchors where before[id] != anchor { changed[id] = wire(anchor) }
    return [
      "anchors": changed,
      "wrote": over.map { ["id": $0.id, "share": ($0.share * 100).rounded() / 100] as [String: Any] },
    ]
  }

  /// What a post now takes away, in the marks' order (`BoardMarkHolds.drops`).
  static func drops(_ marks: [(mark: BoardMark, anchor: BoardMarkAnchor?)], outline: BoardOutline) -> [String: Any] {
    var anchors: [String: BoardMarkAnchor] = [:]
    for (mark, anchor) in marks { anchors[mark.id] = anchor }
    return ["drops": BoardMarkHolds.drops(marks.map(\.mark), anchors: anchors, strokes: outline.strokes).map(\.wire)]
  }
}

#if os(WASI)
  private func marksJSON(_ pointer: UnsafeRawPointer?, _ length: Int32) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any]
  }

  /// `{"mark": {"id", "lines", "pen"?, "label"?}}`: the anchor it takes landing on the loaded outline, as a reply
  /// `{"anchor": {"strokes": [{"name", "x", "y"}], "gap", "written_by"}}`.
  @_expose(wasm, "bw_mark_anchor")
  @_cdecl("bw_mark_anchor")
  public func bwMarkAnchor(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let mark = WebMarks.mark(marksJSON(pointer, length)?["mark"]) else { return reply(json: ["error": "no mark"]) }
    return reply(json: WebMarks.anchor(mark, outline: loaded, texts: outlineTexts, groups: outlineGroups))
  }

  /// `{"marks": [{"id", "anchor"}]}`: where each shows on the loaded outline, as a reply `{"places": {id: {"dx", "dy",
  /// "hidden", "faded", "drops"}}}`.
  @_expose(wasm, "bw_mark_place")
  @_cdecl("bw_mark_place")
  public func bwMarkPlace(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let marks = WebMarks.held(marksJSON(pointer, length)?["marks"], needLines: false) else {
      return reply(json: ["error": "no marks"])
    }
    return reply(json: WebMarks.places(marks, outline: loaded))
  }

  /// `{"stroke": {"id", "points", "width"}, "marks": [{"mark", "anchor"}]}`: the marks Igor's new stroke writes over,
  /// as a reply `{"anchors": {id: anchor}, "wrote": [{"id", "share"}]}`.
  @_expose(wasm, "bw_mark_wrote")
  @_cdecl("bw_mark_wrote")
  public func bwMarkWrote(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    let json = marksJSON(pointer, length)
    guard let raw = json?["stroke"], let stroke = try? WebOutline.ink(raw, 0) else {
      return reply(json: ["error": "no stroke"])
    }
    guard let marks = WebMarks.held(json?["marks"], needLines: true) else { return reply(json: ["error": "no marks"]) }
    return reply(json: WebMarks.wrote(stroke, marks: marks, outline: loaded))
  }

  /// `{"marks": [{"id", "anchor"}]}`: what a post now takes away, as a reply `{"drops": [{"id", "why"}]}`.
  @_expose(wasm, "bw_mark_drops")
  @_cdecl("bw_mark_drops")
  public func bwMarkDrops(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let marks = WebMarks.held(marksJSON(pointer, length)?["marks"], needLines: false) else {
      return reply(json: ["error": "no marks"])
    }
    return reply(json: WebMarks.drops(marks, outline: loaded))
  }
#endif
