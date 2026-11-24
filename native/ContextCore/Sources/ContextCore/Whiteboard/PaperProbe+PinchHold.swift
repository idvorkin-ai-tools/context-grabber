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

  /// Story 1296: fingers that land this soon after the Pencil lifts never pinch, in seconds; the web board's own number
  /// (cockpit-kp5), so the two boards agree.
  public static let pencilLiftSettle: Double = 0.4

  /// Why the board's pinch is held off now, or nil when it may zoom: "pencil" while the Pencil is on the glass, "palm"
  /// while a contact as wide as a palm is, "pencil_lift" when the fingers came within `pencilLiftSettle` of the Pencil
  /// lifting (`sincePencilLift`: seconds since it last lifted, nil if it hasn't).
  public static func pinchHeld(
    pencilDown: Bool, largestFingerRadius: CGFloat, sincePencilLift: Double? = nil
  ) -> String? {
    if pencilDown { return "pencil" }
    if largestFingerRadius >= palmRadius { return "palm" }
    if let since = sincePencilLift, since < pencilLiftSettle { return "pencil_lift" }
    return nil
  }
}
