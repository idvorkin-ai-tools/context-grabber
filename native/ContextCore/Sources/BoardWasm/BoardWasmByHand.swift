//  Room by hand and Larry's picture of a folded board, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 20). `bw_room_by_hand` is `BoardRoom.byHand` over
//  the board `bw_load` keeps: room opens in whole lines, and closing it closes blank paper only (the rigid push, Igor,
//  2026-11-22). `bw_fold_picture` is `BoardOutline.foldPicture` over the outline `bw_outline_load` keeps: the board with
//  every fold open, as Larry's picture draws it. Only the exports are WASI's; the answers build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebByHand {
  /// `{"push": {"cut", "dy"} | null, "cut", "closable"}`: room by hand dragged `dy` at `y` among `ink`, the clear line
  /// it snaps to, and how much blank paper can close there.
  static func room(_ ink: [CGRect], y: CGFloat, dy: CGFloat) -> [String: Any] {
    let cut = BoardRoom.cut(ink, at: y)
    return [
      "push": WebRoom.push(BoardRoom.byHand(ink, at: y, dy: dy)), "cut": Double(cut),
      "closable": Double(BoardRoom.closable(ink, at: cut)),
    ]
  }

  static func box(_ rect: CGRect) -> [Double] {
    [Double(rect.minX), Double(rect.minY), Double(rect.maxX), Double(rect.maxY)]
  }

  /// `{"picture": null}` when no fold shows; else the picture with every fold open: each stroke that moves and by how
  /// much, by name; the ones a fold hid that show; the shaded bands; the folds opened in order (`picture_folds`, the
  /// way back to the folded board); where each folded header's ▸ goes, and each open header's label.
  static func foldPicture(_ outline: BoardOutline) -> [String: Any] {
    guard let picture = outline.foldPicture() else { return ["picture": NSNull()] }
    let name = { (place: Int) -> String? in
      outline.strokes.indices.contains(place) ? outline.strokes[place].ids.first : nil
    }
    var offsets: [String: [Double]] = [:]
    for (place, offset) in picture.offsets where offset.dx != 0 || offset.dy != 0 {
      if let name = name(place) { offsets[name] = [Double(offset.dx), Double(offset.dy)] }
    }
    return [
      "picture": [
        "offsets": offsets, "shown": picture.shown.compactMap(name).sorted(),
        "bands": picture.bands.map {
          ["header": $0.header, "top": Double($0.top), "bottom": Double($0.bottom)] as [String: Any]
        },
        "map": picture.map.wire,
        "folded_marks": picture.foldedMarks.map { ["header": $0.header, "y": Double($0.y)] as [String: Any] },
        "open_labels": picture.openLabels.map {
          ["header": $0.header, "text": $0.text, "box": box($0.box)] as [String: Any]
        },
      ] as [String: Any]
    ]
  }
}

#if os(WASI)
  /// Room by hand dragged `dy` at `y` on the loaded board, as a reply `{"push": null | {"cut", "dy"}, "cut",
  /// "closable"}`; `{"error"}` with nothing loaded.
  @_expose(wasm, "bw_room_by_hand")
  @_cdecl("bw_room_by_hand")
  public func bwRoomByHand(_ y: Double, _ dy: Double) -> UnsafeMutableRawPointer {
    guard let loaded = board else { return reply(json: ["error": "no board is loaded"]) }
    return reply(json: WebByHand.room(loadedBoxes(loaded), y: CGFloat(y), dy: CGFloat(dy)))
  }

  /// The loaded outline with every fold open, as Larry's picture draws it, as a reply `{"picture": null | {...}}`.
  @_expose(wasm, "bw_fold_picture")
  @_cdecl("bw_fold_picture")
  public func bwFoldPicture() -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebByHand.foldPicture(loaded))
  }
#endif
