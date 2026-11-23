//  The web board's outline for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, version 2): its ink with real paths, kept texts and cards as boxes, groups and headers, read into the
//  iPad's own `BoardOutline` so the row a tap is on and what a header folds are the app's answers. Held apart from
//  `bw_load`'s board, whose boxes `bw_cut_y` cuts around. Only the exports are WASI's; the reading builds everywhere,
//  so a plain `swift build` checks it.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

struct WebOutlineUnreadable: Error, CustomStringConvertible {
  let description: String
}

enum WebOutline {
  static func number(_ any: Any?) -> CGFloat? { (any as? NSNumber).map { CGFloat($0.doubleValue) } }

  /// One stroke of ink: `{"id", "points": [[x, y], ...], "width", "hidden", "t"}`, its box its points widened by half
  /// its pen, as `BoardSnapshot` reads the iPad's; `t` when it was made, unix ms, when the host knows.
  static func ink(_ any: Any, _ index: Int) throws -> BoardOps.Stroke {
    guard let entry = any as? [String: Any], let id = entry["id"] as? String else {
      throw WebOutlineUnreadable(description: "stroke \(index) has no id")
    }
    let points = (entry["points"] as? [[Any]] ?? []).compactMap { pair -> CGPoint? in
      guard pair.count >= 2, let x = number(pair[0]), let y = number(pair[1]) else { return nil }
      return CGPoint(x: x, y: y)
    }
    guard let first = points.first else { throw WebOutlineUnreadable(description: "stroke \(id) has no points") }
    let width = number(entry["width"]) ?? 3
    let box = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) {
      $0.union(CGRect(origin: $1, size: .zero))
    }
    return BoardOps.Stroke(
      ids: [id], t: (entry["t"] as? NSNumber)?.int64Value, bounds: box.insetBy(dx: -width / 2, dy: -width / 2),
      hidden: entry["hidden"] as? Bool ?? false, points: points, pen: width)
  }

  /// A kept text or a card, by the box the host measured (text measuring is compiled out on WASI):
  /// `{"id", "box": [left, top, right, bottom], "hidden"}`. It moves whole and is no one's writing.
  static func box(_ any: Any, _ index: Int) throws -> BoardOps.Stroke {
    guard let entry = any as? [String: Any], let id = entry["id"] as? String else {
      throw WebOutlineUnreadable(description: "box \(index) has no id")
    }
    guard let b = entry["box"] as? [Any], b.count == 4, let l = number(b[0]), let t = number(b[1]),
      let r = number(b[2]), let btm = number(b[3])
    else { throw WebOutlineUnreadable(description: "box \(id) has no [left, top, right, bottom]") }
    return BoardOps.Stroke(
      ids: [id], t: nil, bounds: CGRect(x: l, y: t, width: r - l, height: btm - t),
      hidden: entry["hidden"] as? Bool ?? false)
  }

  static func boxText(_ box: BoardOps.Stroke, _ index: Int) -> BoardText {
    BoardText(id: box.ids[0], t: Int64.min + 4 * Int64(index), text: "", font: .plain, size: 0, color: "#000000")
  }

  /// Headers as the iPad keeps them (`BoardHeader`'s own coding): `[{"id", "ids", "mark", "deeper", "ends", "fold": {"ids",
  /// "own", "shift", "lines", "bottom"}}]`.
  static func headers(_ any: Any?) throws -> [BoardHeader] {
    guard let any else { return [] }
    // JSONSerialization traps, not throws, on a top-level value that is not a list or an object.
    guard any is [Any] else { throw WebOutlineUnreadable(description: "the headers could not be read: not a list") }
    do {
      return try JSONDecoder().decode([BoardHeader].self, from: JSONSerialization.data(withJSONObject: any))
    } catch {
      throw WebOutlineUnreadable(description: "the headers could not be read: \(error)")
    }
  }

  /// The web board as `{"strokes", "boxes", "groups": {name: group}, "headers"}`: ink first, then the boxes.
  static func outline(json any: Any) throws -> BoardOutline { try parts(json: any).outline }

  /// The outline, and the kept texts and groups it was made with (the outline keeps them to itself).
  static func parts(json any: Any) throws -> (outline: BoardOutline, texts: [BoardText], groups: [String: String]) {
    guard let json = any as? [String: Any] else {
      throw WebOutlineUnreadable(description: "an outline is a JSON object")
    }
    let ink = try (json["strokes"] as? [Any] ?? []).enumerated().map { try Self.ink($1, $0) }
    let boxes = try (json["boxes"] as? [Any] ?? []).enumerated().map { try box($1, $0) }
    let headers = try Self.headers(json["headers"])
    var groups = json["groups"] as? [String: String] ?? [:]
    for id in boxes.flatMap(\.ids) where groups[id] == nil { groups[id] = id }
    // Each box is a kept text to the outline, so a hold on it is on it anywhere inside (`word(at:)`, `group(at:)`), as
    // on the iPad. Its time is one no stroke can have (far before 1970), so it owns no glyphs: the box is the whole of
    // it.
    let texts = boxes.enumerated().map { boxText($1, $0) }
    return (BoardOutline(strokes: ink + boxes, headers: headers, texts: texts, groups: groups), texts, groups)
  }

  static func strokes(json any: Any) throws -> [BoardOps.Stroke] {
    guard let list = (any as? [String: Any])?["strokes"] as? [Any] else {
      throw WebOutlineUnreadable(description: "the strokes could not be read: no strokes list")
    }
    return try list.enumerated().map { try ink($1, $0) }
  }

  /// The row of ink at `y` (`BoardOutline.row(at:)`): `{"row": null}` on blank paper.
  static func row(_ outline: BoardOutline, at y: CGFloat) -> [String: Any] {
    guard let row = outline.row(at: y) else { return ["row": NSNull()] }
    var out: [String: Any] = ["top": Double(row.top), "bottom": Double(row.bottom)]
    if let header = row.header { out["header"] = header } else { out["names"] = row.names }
    return ["row": out]
  }

  /// What folding header `id` would do (`BoardOutline.fold`, on a copy: the loaded outline stays as it is):
  /// `{"fold": null}` when there is nothing to fold.
  static func fold(_ outline: BoardOutline, _ id: String) -> [String: Any] {
    var folded = outline
    guard folded.fold(id), let f = folded.header(id)?.fold else { return ["fold": NSNull()] }
    return [
      "fold": [
        "ids": f.ids, "own": f.own, "shift": Double(f.shift), "lines": f.lines, "bottom": Double(f.bottom),
      ] as [String: Any]
    ]
  }
}

#if os(WASI)
  /// The loaded outline, and why the last outline call failed.
  var outline: BoardOutline?
  /// The loaded outline's kept texts and groups, which it keeps to itself.
  var outlineTexts: [BoardText] = []
  var outlineGroups: [String: String] = [:]

  /// Replaces the loaded outline. The number of strokes and boxes read, or -1 with nothing loaded.
  @_expose(wasm, "bw_outline_load")
  @_cdecl("bw_outline_load")
  public func bwOutlineLoad(_ pointer: UnsafeRawPointer?, _ length: Int32) -> Int32 {
    outline = nil
    lastError = nil
    do {
      let read = try WebOutline.parts(json: JSONSerialization.jsonObject(with: input(pointer, length)))
      outline = read.outline
      outlineTexts = read.texts
      outlineGroups = read.groups
      return Int32(read.outline.strokes.count)
    } catch {
      return failed("the outline could not be read: \(error)")
    }
  }

  /// `{"strokes": [...]}`, new ink added to the loaded outline. The number of strokes and boxes now, or -1 with the
  /// outline as it was.
  @_expose(wasm, "bw_outline_add")
  @_cdecl("bw_outline_add")
  public func bwOutlineAdd(_ pointer: UnsafeRawPointer?, _ length: Int32) -> Int32 {
    lastError = nil
    guard var loaded = outline else { return failed("no outline is loaded") }
    do {
      loaded.strokes += try WebOutline.strokes(json: JSONSerialization.jsonObject(with: input(pointer, length)))
      outline = loaded
      return Int32(loaded.strokes.count)
    } catch {
      return failed("the strokes could not be read: \(error)")
    }
  }

  /// The row a tap at `y` is on, as a reply; `{"error"}` with nothing loaded.
  @_expose(wasm, "bw_row_at")
  @_cdecl("bw_row_at")
  public func bwRowAt(_ y: Double) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebOutline.row(loaded, at: CGFloat(y)))
  }

  /// `{"id"}`: what folding that header would do, as a reply; `{"error"}` with nothing loaded.
  @_expose(wasm, "bw_fold")
  @_cdecl("bw_fold")
  public func bwFold(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    guard let json = try? JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any],
      let id = json["id"] as? String
    else { return reply(json: ["error": "no header id"]) }
    return reply(json: WebOutline.fold(loaded, id))
  }
#endif
