//  Story 1145 (bead context-grabber-eg7v): a move the system made on its own, PaperKit's handwriting reflow above all,
//  never carries Igor's ink and Larry's (or Claude's) together. On the iPad the reflow took Larry's 52-stroke text and two
//  of Igor's strokes for one line, and a drag moved all 54; Igor kept the reflow but not the mixing.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension PaperProbe {
  /// What the rule made of one move: split it, or why not, and which strokes go back.
  public struct OwnersApart: Equatable, Sendable {
    public enum Verdict: String, Sendable {
      /// Both owners' ink moved, not of Igor's choosing: one owner's goes back.
      case split
      /// Only one owner's ink moved.
      case oneOwner = "one_owner"
      /// Every moved stroke was selected: a drag of what Igor picked, moved whole.
      case selected
      /// No stroke on the board is known as Larry's or Claude's, so the owners can't be told apart.
      case theirsUnknown = "theirs_unknown"
      case nothingMoved = "nothing_moved"
    }

    public var verdict: Verdict
    /// The moved strokes that go back where they were, by key; empty unless split.
    public var putBack: Set<String>
    /// The strokes going back are Larry's or Claude's (else Igor's).
    public var putBackTheirs: Bool

    public init(verdict: Verdict, putBack: Set<String> = [], putBackTheirs: Bool = false) {
      self.verdict = verdict
      self.putBack = putBack
      self.putBackTheirs = putBackTheirs
    }
  }

  /// The owners kept apart in `moved`: `held` is what was selected (as the touch went down, or now), `theirs` the keys of
  /// Larry's and Claude's strokes. The owner with more of the moved strokes keeps the move and the other's go back; on a
  /// tie Igor's keeps it.
  public static func ownersApart(_ moved: [InkMove], held: Set<String>, theirs: Set<String>) -> OwnersApart {
    let ids = Set(moved.map(\.id))
    guard !ids.isEmpty else { return OwnersApart(verdict: .nothingMoved) }
    guard !ids.isSubset(of: held) else { return OwnersApart(verdict: .selected) }
    guard !theirs.isEmpty else { return OwnersApart(verdict: .theirsUnknown) }
    let theirsMoved = ids.intersection(theirs)
    let mineMoved = ids.subtracting(theirs)
    guard !theirsMoved.isEmpty, !mineMoved.isEmpty else { return OwnersApart(verdict: .oneOwner) }
    let theirsGoBack = theirsMoved.count <= mineMoved.count
    return OwnersApart(
      verdict: .split, putBack: theirsGoBack ? theirsMoved : mineMoved, putBackTheirs: theirsGoBack)
  }
}
