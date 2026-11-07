//  Story 306: a chat picture opened full size closes on a swipe down. The view's drag asks this; Done closes it too.

import Foundation

public enum ChatImageClose {
  /// How far a finger moves, in points, before the picture counts it as a drag rather than a tap.
  public static let minimumDrag: CGFloat = 30

  /// Whether a drag that ended `height` points lower than it began closes the picture: down past 80 points does; a
  /// swipe up, a short one or one that comes back leaves the picture open.
  public static func closes(dragHeight height: CGFloat) -> Bool { height > 80 }
}
