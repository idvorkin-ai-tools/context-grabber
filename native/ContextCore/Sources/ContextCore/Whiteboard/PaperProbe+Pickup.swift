//  Whether a move PaperKit reports was a drop by hand (story 1172, bead context-grabber-9uj2): Igor's drag of a piece of
//  ink or text, however he picked it up, as against the system rearranging handwriting. On the iPad, 2026-11-22, a kept
//  text of Larry's dragged from PaperKit's handwriting view onto Igor's writing arrived with nothing selected, and the
//  board took it for no drop at all. Pure.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension PaperProbe {
  /// How a move was picked up, or why it is no drop; the raw value goes in the log.
  public enum Pickup: String, Sendable {
    /// Everything that moved was selected: a lasso, or a tap on a group or a kept text.
    case selected
    /// Nothing selected held it, but it all moved together by the same amount while a touch was down.
    case dragged
    /// Nothing moved.
    case notAMove = "not_a_move"
    /// His ink and Larry's moved together: put right first (story 1145), and no room opens.
    case split
    /// No touch was down: the system moved it.
    case notInTouch = "not_in_touch"
    /// The strokes moved by different amounts: the system rearranged handwriting.
    case notRigid = "not_rigid"

    /// A drop that can open room.
    public var isDrop: Bool { self == .selected || self == .dragged }
  }

  /// How far apart two strokes' moves can be and still be one drag: a stroke's frame is its rendered bounds, and a
  /// drag that PaperKit also re-measured (it logged `resized` on a plain drag) shifts one edge by a point or so.
  public static let rigidTolerance: CGFloat = 2

  /// Story 1172: a drop by hand is a move of only selected strokes, or, with nothing selected holding them, a move of
  /// strokes that all went the same way the same distance while a touch was down. `split`: the move carried both
  /// owners' ink (story 1145).
  public static func pickup(_ moved: [InkMove], selected: Set<String>, inTouch: Bool, split: Bool) -> Pickup {
    guard let first = moved.first else { return .notAMove }
    if split { return .split }
    if Set(moved.map(\.id)).isSubset(of: selected) { return .selected }
    guard inTouch else { return .notInTouch }
    let rigid = moved.allSatisfy {
      abs($0.dx - first.dx) <= rigidTolerance && abs($0.dy - first.dy) <= rigidTolerance
    }
    return rigid ? .dragged : .notRigid
  }
}
