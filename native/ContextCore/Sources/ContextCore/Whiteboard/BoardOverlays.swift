//  Larry's controls on the board (spec 2026-11-16-whiteboard-board-ops-design.md, *Bands, chips, buttons and hints*,
//  stories 845, 846): a band, chip, button or hint at a place on the board, with a label, his style and the event a tap
//  on it sends him. Not ink: never in the picture or the strokes, never undone, gone when the board closes.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct BoardOverlay: Equatable, Sendable {
  public enum Kind: String, Sendable { case band, chip, button, hint }

  public static let longestLabel = 200

  public var id: String
  public var kind: Kind
  /// In board points, top-left origin.
  public var rect: CGRect
  public var label: String
  /// As Larry wrote it; the app reads `color`, `fill` (`#rrggbb`) and nothing else.
  public var style: BoardMeta?
  /// Sent to him, as he wrote it, when Igor taps it.
  public var tapEvent: BoardMeta?

  public init(
    id: String, kind: Kind, rect: CGRect, label: String = "", style: BoardMeta? = nil, tapEvent: BoardMeta? = nil
  ) {
    self.id = id
    self.kind = kind
    self.rect = rect
    self.label = label
    self.style = style
    self.tapEvent = tapEvent
  }

  /// An `overlay` op's fields; nil for one that can't be shown.
  init?(_ json: [String: Any]) {
    let field = { (r: [String: Any], key: String) in r[key].flatMap(WhiteboardTurn.number) }
    guard let id = json["id"] as? String, !id.isEmpty, let kind = (json["kind"] as? String).flatMap(Kind.init),
      let r = json["rect"] as? [String: Any], let x = field(r, "x"), let y = field(r, "y"), let w = field(r, "w"),
      let h = field(r, "h"), w > 0, h > 0
    else { return nil }
    let label = json["label"] as? String ?? ""
    guard label.count <= Self.longestLabel else { return nil }
    var style: BoardMeta?
    if let raw = json["style"] {
      guard let parsed = BoardMeta(raw) else { return nil }
      style = parsed
    }
    var tap: BoardMeta?
    if let raw = json["tap_event"] {
      guard let parsed = BoardMeta(raw) else { return nil }
      tap = parsed
    }
    self.init(
      id: id, kind: kind, rect: CGRect(x: x, y: y, width: w, height: h), label: label, style: style, tapEvent: tap)
  }

  /// `#rrggbb` from his style, as `0xRRGGBB`.
  public func styleColor(_ key: String) -> UInt32? {
    (style?.object as? [String: Any]).flatMap { WhiteboardTurn.hexColor($0[key]) }
  }
}

public struct BoardOverlays: Equatable, Sendable {
  public enum Change: Equatable, Sendable {
    case set(BoardOverlay)
    case remove(String)
  }

  /// In the order laid: the last is on top.
  public private(set) var list: [BoardOverlay] = []

  public init() {}

  public mutating func apply(_ changes: [Change]) {
    for change in changes {
      switch change {
      case .set(let overlay):
        list.removeAll { $0.id == overlay.id }
        list.append(overlay)
      case .remove(let id):
        list.removeAll { $0.id == id }
      }
    }
  }

  /// The topmost control under a board point, within `tolerance` of its edge.
  public func hit(_ point: CGPoint, tolerance: CGFloat = 0) -> BoardOverlay? {
    list.last { $0.rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
  }
}
