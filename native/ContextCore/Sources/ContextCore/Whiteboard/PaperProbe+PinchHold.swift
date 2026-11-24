//  Story 1284 (context-grabber-hxzv): writing never zooms the board; only a pinch of two fingertips does.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension PaperProbe {
  /// A finger contact this wide or wider is a palm, in points. On Igor's iPad, 2026-11-22..24, fingertips read 31.3 to
  /// 52.2 (his deliberate pinches) and a resting palm 62.7 to 125.3; every zoom with one down came while he wrote.
  public static let palmRadius: CGFloat = 60

  /// Why the board's pinch is held off now, or nil when it may zoom: "pencil" while the Pencil is on the glass, "palm"
  /// while a contact as wide as a palm is.
  public static func pinchHeld(pencilDown: Bool, largestFingerRadius: CGFloat) -> String? {
    if pencilDown { return "pencil" }
    return largestFingerRadius >= palmRadius ? "palm" : nil
  }
}
