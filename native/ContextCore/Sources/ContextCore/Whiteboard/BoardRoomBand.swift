//  What the room handle shows while it is held (spec 2026-11-01-whiteboard-design.md, *Every pen gesture shows what it
//  did (#1000)*; stories 1044–1046): the see-through band where the room a lift would open (or close) lies, and the
//  chip's words. The band is `BoardRoom.byHand`'s own answer, so what it shows is what the lift does. Pure.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct BoardRoomBand: Equatable, Sendable {
  public enum Kind: String, Sendable {
    /// Dragged down, or not yet half a line: room opens.
    case opening
    /// Dragged up over blank paper: it closes.
    case closing
    /// Dragged up where there is no blank paper to close.
    case nothingToClose = "nothing_to_close"
  }

  /// The clear line the room opens at, board points.
  public var cut: CGFloat
  /// The room a lift right now would open (down) or close (up), in whole lines; zero is a thin line at `cut`.
  public var dy: CGFloat
  public var kind: Kind

  public init(cut: CGFloat, dy: CGFloat, kind: Kind) {
    self.cut = cut
    self.dy = dy
    self.kind = kind
  }

  /// The band's top and height, board points: below the cut when opening, above it when closing.
  public var top: CGFloat { min(cut, cut + dy) }
  public var height: CGFloat { abs(dy) }
  /// Whole lines.
  public var lines: Int { Int((height / BoardRoom.line).rounded()) }

  /// The chip's words.
  public var label: String {
    switch kind {
    case .opening: "Making room"
    case .closing: "Closing room"
    case .nothingToClose: "No blank paper to close"
    }
  }

  /// The band for a handle held at board `y` and dragged `dy` board points so far, among `ink` (the boxes of what moves
  /// whole, as `byHand` takes them).
  public static func held(_ ink: [CGRect], at y: CGFloat, dy: CGFloat) -> BoardRoomBand {
    if let push = BoardRoom.byHand(ink, at: y, dy: dy) {
      return BoardRoomBand(cut: push.cut, dy: push.dy, kind: push.dy > 0 ? .opening : .closing)
    }
    let cut = BoardRoom.cut(ink, at: y)
    // Under half a line either way moves nothing yet: the handle is still opening room.
    let up = (dy / BoardRoom.line).rounded() < 0
    return BoardRoomBand(cut: cut, dy: 0, kind: up ? .nothingToClose : .opening)
  }
}
