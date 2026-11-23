//  Story 1143 (bead context-grabber-eg7v): a change that moved ink, set against what the touch held when it went down
//  and whose ink it was, for the log. On the iPad one finger drag moved Larry's text and two of Igor's strokes with nothing
//  selected; this is what the next such line has to say.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension PaperProbe {
  /// How far apart two strokes' moves can be, in board points, and still be one drag.
  public static let movedAlikeSlack: CGFloat = 1

  /// The log's fields for `moved`: how many were selected when the touch began (`held`) and how many weren't, how many
  /// are Larry's or Claude's (`theirs`) and how many Igor's, the box they now fill (from `frames`), the least and most
  /// each went, whether they all went alike (a drag) or each its own way (writing rewrapped), and how many changed size.
  /// Empty with nothing moved.
  public static func moveAudit(
    _ moved: [InkMove], held: Set<String>, theirs: Set<String>, frames: [String: CGRect]
  ) -> [String: Any] {
    guard !moved.isEmpty else { return [:] }
    let ids = moved.map(\.id)
    let wasHeld = ids.filter(held.contains).count
    let isTheirs = ids.filter(theirs.contains).count
    let dxs = moved.map(\.dx)
    let dys = moved.map(\.dy)
    let box = ids.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    let (dxLo, dxHi, dyLo, dyHi) = (dxs.min() ?? 0, dxs.max() ?? 0, dys.min() ?? 0, dys.max() ?? 0)
    return [
      "moved_held": wasHeld, "moved_not_held": ids.count - wasHeld, "moved_theirs": isTheirs,
      "moved_mine": ids.count - isTheirs,
      "moved_box": box.isNull ? [] : [box.minX, box.minY, box.width, box.height].map(tenths),
      "dx_min": tenths(dxLo), "dx_max": tenths(dxHi), "dy_min": tenths(dyLo), "dy_max": tenths(dyHi),
      "moved_alike": dxHi - dxLo <= movedAlikeSlack && dyHi - dyLo <= movedAlikeSlack,
      "resized": moved.filter(\.resized).count,
    ]
  }

  private static func tenths(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }
}
