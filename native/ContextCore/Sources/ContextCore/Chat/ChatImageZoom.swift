//  Story 821 (#907): a chat picture opened full size pinches, double taps and pans. The view's gestures ask this;
//  scales are times the fitted size, offsets are points from the screen's centre.

import Foundation

public enum ChatImageZoom {
  public static let most: CGFloat = 5
  /// A double tap from fitted goes to this.
  public static let doubleTap: CGFloat = 2.5
  /// While held, a pinch closed past fitted shows smaller, down to this, then settles to fitted on letting go.
  static let leastWhileHeld: CGFloat = 0.5

  /// The scale shown while a pinch is held.
  public static func pinching(_ scale: CGFloat) -> CGFloat { min(max(scale, leastWhileHeld), most) }

  /// Where a scale settles once the fingers let go: fitted at the least, five times at the most.
  public static func settled(_ scale: CGFloat) -> CGFloat { min(max(scale, 1), most) }

  /// A double tap zooms a fitted picture and takes a zoomed one back to fitted.
  public static func doubleTapped(_ scale: CGFloat) -> CGFloat { scale > 1 ? 1 : doubleTap }

  /// The picture's size when it fits the screen, keeping its shape.
  public static func fitted(_ picture: CGSize, in screen: CGSize) -> CGSize {
    guard picture.width > 0, picture.height > 0 else { return .zero }
    let fit = min(screen.width / picture.width, screen.height / picture.height)
    return CGSize(width: picture.width * fit, height: picture.height * fit)
  }

  /// The offset kept within the zoomed picture's overflow, so its edge never comes inside the screen's.
  public static func clamped(_ offset: CGSize, scale: CGFloat, picture fitted: CGSize, in screen: CGSize) -> CGSize {
    let spareX = max(0, (fitted.width * scale - screen.width) / 2)
    let spareY = max(0, (fitted.height * scale - screen.height) / 2)
    return CGSize(width: min(max(offset.width, -spareX), spareX), height: min(max(offset.height, -spareY), spareY))
  }

  /// The offset that keeps the point under the fingers (`anchor`, from the screen's centre) still as the scale changes.
  public static func anchored(_ offset: CGSize, around anchor: CGPoint, from old: CGFloat, to new: CGFloat) -> CGSize {
    guard old > 0 else { return offset }
    let ratio = new / old
    return CGSize(
      width: anchor.x - (anchor.x - offset.width) * ratio, height: anchor.y - (anchor.y - offset.height) * ratio)
  }

  /// The scale as the session log writes it, to two places.
  public static func logged(_ scale: CGFloat) -> Double { (Double(scale) * 100).rounded() / 100 }
}
