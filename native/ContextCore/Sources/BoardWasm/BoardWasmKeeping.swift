//  Keeping Larry's marks and Tidy overlaps, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md,
//  The interface, version 14): Keep all's groups and the one room it opens (`WhiteboardMarks.keptGroups`,
//  `BoardRoom.late` for several replies at once), and how far Tidy moves each label (`WhiteboardTidy.tidy`), over the
//  outline `bw_outline_load` keeps. Only the exports are WASI's; the answers build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebKeeping {
  /// One of Larry's marks being kept: its name (`<reply>#<index>`, as `WhiteboardMarks.mark` names it), its box with
  /// half its pen round it, and when the picture its reply answers was taken (unix ms), if known.
  struct Mark: Equatable {
    var id: String
    var box: CGRect
    var seen: Int64?
  }

  /// `[{"id", "box": [left, top, right, bottom], "seen"?}]`, or nil when any of them can't be read.
  static func marks(_ any: Any?) -> [Mark]? {
    guard let list = any as? [Any] else { return nil }
    var out: [Mark] = []
    for entry in list {
      guard let mark = entry as? [String: Any], let id = mark["id"] as? String, let box = WebConnectors.box(mark["box"])
      else { return nil }
      out.append(Mark(id: id, box: box, seen: JSONNumber(mark["seen"])?.int64Value))
    }
    return out
  }

  /// Keep all: `{"groups": {mark: group}, "push": {"cut", "dy"} | null, "covered"}`. A reply with two or more of the
  /// marks is kept as one group, named as the app names it; a lone mark is kept on its own and not named. One room for
  /// all of them: whatever Igor made after a mark's own picture under it, or that a text of Larry's in `landing` sits
  /// on, goes down whole lines until it is half a line under the lowest. Nothing in `theirs` (unix ms) ever makes room.
  static func keepAll(
    _ outline: BoardOutline, texts: [BoardText], groups: [String: String], marks: [Mark], landing: [CGRect],
    theirs: Set<Int64>
  ) -> [String: Any] {
    let kept = WhiteboardMarks.keptGroups(marks.map(\.id)).mapValues(WhiteboardMarks.group(reply:))
    let late = BoardRoom.late(
      marks.map { (box: $0.box, seen: $0.seen) }, landing: landing, strokes: outline.strokes, texts: texts,
      groups: groups, folds: outline.tags, theirs: theirs)
    return ["groups": kept, "push": WebRoom.push(late.push), "covered": late.covered]
  }

  /// A box as ink over the whole of it: a line across it every few points, top to bottom, so anything inside it is on
  /// ink, as a kept text's glyphs are on the iPad.
  static func filled(_ box: CGRect) -> [[CGPoint]] {
    var ys = Array(stride(from: box.minY, to: box.maxY, by: 4))
    ys.append(box.maxY)
    return ys.map { [CGPoint(x: box.minX, y: $0), CGPoint(x: box.maxX, y: $0)] }
  }

  /// Tidy overlaps: `{"moves": {label: dy}}`, how far down each of `labels` (names in the outline) goes to sit on no
  /// ink, laid out top to bottom; one that sits clear isn't named. Everything else that shows is ink; what is hidden is
  /// neither. A label in a group stays with its group, as ink. A kept text or card is ink over its whole box.
  static func tidy(_ outline: BoardOutline, groups: [String: String], labels names: [String]) -> [String: Any] {
    let wanted = Set(names)
    var labels: [String: [[CGPoint]]] = [:]
    var ink: [[CGPoint]] = []
    for stroke in outline.strokes where !stroke.hidden {
      let lines = stroke.points.isEmpty ? filled(stroke.bounds) : [stroke.points]
      let name = stroke.ids[0]
      // A box is its own group to the outline; only a group of more than itself holds a label.
      if wanted.contains(name), groups[name].map({ $0 == name }) ?? true {
        labels[name, default: []] += lines
      } else {
        ink += lines
      }
    }
    return ["moves": WhiteboardTidy.tidy(labels, among: ink).mapValues { Double($0) }]
  }
}

#if os(WASI)
  /// `{"marks": [{"id", "box", "seen"?}], "landing"?: [box], "theirs"?: [ms]}`: Keep all over the loaded outline, as a
  /// reply.
  @_expose(wasm, "bw_keep_all")
  @_cdecl("bw_keep_all")
  public func bwKeepAll(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let marks = WebKeeping.marks(json["marks"])
    else { return reply(json: ["error": "no marks"]) }
    let landing = (json["landing"] as? [Any] ?? []).compactMap(WebConnectors.box)
    let theirs = Set((json["theirs"] as? [Any] ?? []).compactMap { JSONNumber($0)?.int64Value })
    return reply(
      json: WebKeeping.keepAll(
        loaded, texts: outlineTexts, groups: outlineGroups, marks: marks, landing: landing, theirs: theirs))
  }

  /// `{"labels": [name]}`: how far Tidy overlaps moves each, over the loaded outline, as a reply.
  @_expose(wasm, "bw_tidy")
  @_cdecl("bw_tidy")
  public func bwTidy(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let labels = json["labels"] as? [String]
    else { return reply(json: ["error": "no labels"]) }
    return reply(json: WebKeeping.tidy(loaded, groups: outlineGroups, labels: labels))
  }
#endif
