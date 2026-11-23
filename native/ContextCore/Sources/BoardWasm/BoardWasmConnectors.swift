//  A connector's route, for the Cockpit's ink board (spec 2026-11-22-board-rules-on-the-web-design.md, The interface,
//  version 6): `BoardConnectors.route`, from the two ends' boxes, the sides they leave and enter, and the boxes in the
//  way. Plain numbers in and out; no board is needed. Only the export is WASI's; the answer builds everywhere.

import BoardCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum WebConnectors {
  /// `[left, top, right, bottom]` as a box, nil when it isn't four numbers.
  static func box(_ any: Any?) -> CGRect? {
    guard let b = any as? [Any], b.count == 4 else { return nil }
    let n = b.compactMap { ($0 as? NSNumber).map { CGFloat($0.doubleValue) } }
    guard n.count == 4 else { return nil }
    return CGRect(x: n[0], y: n[1], width: n[2] - n[0], height: n[3] - n[1])
  }

  /// `{"from": box, "to": box, "fromSide", "toSide", "obstacles": [box]}` to `{"points": [[x, y], ...]}`, or
  /// `{"error"}` when it can't be read.
  static func route(_ json: Any?) -> [String: Any] {
    guard let json = json as? [String: Any], let a = box(json["from"]), let b = box(json["to"]) else {
      return ["error": "no from and to boxes"]
    }
    let side = { (key: String) in (json[key] as? String).flatMap(BoardConnector.Side.init(rawValue:)) ?? .center }
    let obstacles = (json["obstacles"] as? [Any] ?? []).compactMap(box)
    let points = BoardConnectors.route(
      from: a, to: b, fromSide: side("fromSide"), toSide: side("toSide"), obstacles: obstacles)
    return ["points": points.map { [Double($0.x), Double($0.y)] }]
  }
}

#if os(WASI)
  /// A connector's route (`WebConnectors.route`), as a reply.
  @_expose(wasm, "bw_route_connector")
  @_cdecl("bw_route_connector")
  public func bwRouteConnector(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    reply(json: WebConnectors.route(try? JSONSerialization.jsonObject(with: input(pointer, length))))
  }
#endif
