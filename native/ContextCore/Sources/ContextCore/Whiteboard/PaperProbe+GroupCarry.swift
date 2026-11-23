//  Story 998 (bead context-grabber-1xdh): a group moves as one, whoever moves it. On the iPad, 2026-11-22, a finger drag
//  on PaperKit's handwriting view with nothing selected moved 102 of a kept reply's 120 strokes, one paragraph of it, and
//  left the rest of the group where it was. A drag by hand that picks up part of a group brings the rest along. Pure.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension PaperProbe {
  /// What a drag by hand brings along: the strokes of each group it moved only part of, by key, and how far.
  public struct GroupCarry: Equatable, Sendable {
    /// The strokes left behind, by key, to move by `dx`, `dy`.
    public var carry: Set<String>
    /// The groups made whole again, by name, sorted.
    public var groups: [String]
    public var dx: CGFloat
    public var dy: CGFloat

    public init(carry: Set<String>, groups: [String], dx: CGFloat, dy: CGFloat) {
      self.carry = carry
      self.groups = groups
      self.dx = dx
      self.dy = dy
    }
  }

  /// Story 998: for `moved`, a drag by hand that moved its strokes together (a pickup of `dragged`), the rest of every
  /// group it moved part of, moved as far as the drag went. `groupOf`: each stroke's group by key, for every stroke on
  /// the board in a group. Nil when the drag took no group, or every group it took whole.
  public static func groupCarry(_ moved: [InkMove], groupOf: [String: String]) -> GroupCarry? {
    guard let first = moved.first else { return nil }
    let ids = Set(moved.map(\.id))
    let taken = Set(ids.compactMap { groupOf[$0] })
    guard !taken.isEmpty else { return nil }
    let left = groupOf.filter { taken.contains($0.value) && !ids.contains($0.key) }
    guard !left.isEmpty else { return nil }
    return GroupCarry(
      carry: Set(left.keys), groups: Set(left.values).sorted(), dx: first.dx, dy: first.dy)
  }
}
