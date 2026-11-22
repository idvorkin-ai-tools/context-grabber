//  Story 729 (#781): chat's text size on the Mac, one of the system's text sizes, stepped by Command+= and Command+Minus.

import Foundation

public enum ChatTextSize {
  /// The system's text sizes, smallest first: x-small … xxx-large, then the five accessibility sizes. The app maps a
  /// step to the matching `DynamicTypeSize` in this order.
  public static let steps = 12
  /// Large, the system's own default.
  public static let standard = 3
  /// Where the size is remembered on this Mac.
  public static let defaultsKey = "chat_text_size"

  /// A remembered value, or the default when nothing (or something out of range) was remembered.
  public static func restored(_ saved: Int?) -> Int {
    guard let saved, (0..<steps).contains(saved) else { return standard }
    return saved
  }

  /// One size bigger, staying at the largest.
  public static func bigger(_ step: Int) -> Int { min(step + 1, steps - 1) }
  /// One size smaller, staying at the smallest.
  public static func smaller(_ step: Int) -> Int { max(step - 1, 0) }
  public static func canGrow(_ step: Int) -> Bool { step < steps - 1 }
  public static func canShrink(_ step: Int) -> Bool { step > 0 }
}
