//  Where a paste lands and the room a drop opens, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 3): `BoardRoom.place` and `BoardRoom.drop` over
//  the board `bw_load` keeps, asked with plain numbers. The host measures the text (text measuring is compiled out on
//  WASI) and sends the block's size. Only the exports are WASI's; the answers build everywhere.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebRoom {
  static func push(_ push: BoardRoom.Push?) -> Any {
    guard let push else { return NSNull() }
    return ["cut": Double(push.cut), "dy": Double(push.dy)]
  }

  /// Where a block of `size` lands in `view` among `ink` (`BoardRoom.place`): its top-left and the room opened for it.
  static func place(_ size: CGSize, view: CGRect, ink: [CGRect]) -> [String: Any] {
    let landing = BoardRoom.place(size, view: view, ink: ink)
    return ["x": Double(landing.origin.x), "y": Double(landing.origin.y), "push": push(landing.push)]
  }

  /// The room ink dropped at `block`, lifted from `from`, opens among `ink` (`BoardRoom.drop`).
  static func drop(_ block: CGRect, from: CGRect, ink: [CGRect]) -> [String: Any] {
    ["push": push(BoardRoom.drop(block, from: from, among: ink))]
  }

  static func rect(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> CGRect {
    CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left), height: CGFloat(bottom - top))
  }
}

#if os(WASI)
  /// A paste of `w` by `h` in the view `left, top, right, bottom`: where it lands among the loaded board's boxes, as a
  /// reply `{"x", "y", "push": null | {"cut", "dy"}}`; `{"error"}` with nothing loaded.
  @_expose(wasm, "bw_place")
  @_cdecl("bw_place")
  public func bwPlace(
    _ w: Double, _ h: Double, _ left: Double, _ top: Double, _ right: Double, _ bottom: Double
  ) -> UnsafeMutableRawPointer {
    guard let loaded = board else { return reply(json: ["error": "no board is loaded"]) }
    let size = CGSize(width: CGFloat(w), height: CGFloat(h))
    return reply(json: WebRoom.place(size, view: WebRoom.rect(left, top, right, bottom), ink: loadedBoxes(loaded)))
  }

  /// Ink dropped at the block `bl, bt, br, bb`, lifted from `fl, ft, fr, fb`, the loaded board being everything else:
  /// the room it opens, as a reply `{"push": null | {"cut", "dy"}}`; `{"error"}` with nothing loaded.
  @_expose(wasm, "bw_drop")
  @_cdecl("bw_drop")
  public func bwDrop(
    _ bl: Double, _ bt: Double, _ br: Double, _ bb: Double, _ fl: Double, _ ft: Double, _ fr: Double, _ fb: Double
  ) -> UnsafeMutableRawPointer {
    guard let loaded = board else { return reply(json: ["error": "no board is loaded"]) }
    return reply(
      json: WebRoom.drop(WebRoom.rect(bl, bt, br, bb), from: WebRoom.rect(fl, ft, fr, fb), ink: loadedBoxes(loaded)))
  }
#endif
