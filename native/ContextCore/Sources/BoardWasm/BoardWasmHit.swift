//  What the Pencil or a finger held still is on, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 5): `BoardOutline.word(at:)` (what a Pencil
//  hold picks up) and `holdMenu(at:)` (what a finger hold offers), over the outline `bw_outline_load` keeps. Only the
//  exports are WASI's; the answers build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebHit {
  /// `{"names": [...]}` for what a Pencil held at (x, y) picks up, `{"names": null}` off ink.
  static func word(_ outline: BoardOutline, x: Double, y: Double, slop: Double) -> [String: Any] {
    guard let names = outline.word(at: CGPoint(x: x, y: y), slop: CGFloat(slop)) else { return ["names": NSNull()] }
    return ["names": names]
  }

  /// The menu a finger held at (x, y) brings up: `{"choices": [id], "names", "on"}`, each choice by its id
  /// (`select`, `delete`, `make-room`, `paste`, `make-header`, `not-header`, `fold-all`, `level-n`, `unfold-all`), and
  /// `header`, the header *Not a header* takes, when there is one.
  static func holdMenu(_ outline: BoardOutline, x: Double, y: Double, inMargin: Bool, slop: Double) -> [String: Any] {
    let menu = outline.holdMenu(at: CGPoint(x: x, y: y), inMargin: inMargin, slop: CGFloat(slop))
    var out: [String: Any] = ["choices": menu.choices.map(\.id), "names": menu.names, "on": menu.on]
    for case .notHeader(let id) in menu.choices { out["header"] = id }
    return out
  }
}

#if os(WASI)
  /// What a Pencil held still at (x, y) picks up, within `slop` of ink, as a reply.
  @_expose(wasm, "bw_word_at")
  @_cdecl("bw_word_at")
  public func bwWordAt(_ x: Double, _ y: Double, _ slop: Double) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebHit.word(loaded, x: x, y: y, slop: slop))
  }

  /// The menu a finger held still at (x, y) brings up (`inMargin` nonzero left of the margin's edge), as a reply.
  @_expose(wasm, "bw_hold_menu")
  @_cdecl("bw_hold_menu")
  public func bwHoldMenu(_ x: Double, _ y: Double, _ inMargin: Int32, _ slop: Double) -> UnsafeMutableRawPointer {
    guard let loaded = outline else { return reply(json: ["error": "no outline is loaded"]) }
    return reply(json: WebHit.holdMenu(loaded, x: x, y: y, inMargin: inMargin != 0, slop: slop))
  }
#endif
