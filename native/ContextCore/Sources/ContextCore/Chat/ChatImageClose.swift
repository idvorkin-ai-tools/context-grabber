//  Story 306: a chat picture opened full size closes on a swipe down. The view's drag asks this; Done closes it too.
//  Story 821: only when fitted; zoomed in, the drag pans (`ChatImageZoom`).

import Foundation

public enum ChatImageClose {
  /// How far a finger moves, in points, before the picture counts it as a drag rather than a tap.
  public static let minimumDrag: CGFloat = 30

  /// Whether a drag that ended `height` points lower than it began closes the picture: down past 80 points does; a
  /// swipe up, a short one or one that comes back leaves the picture open.
  public static func closes(dragHeight height: CGFloat) -> Bool { height > 80 }

  /// The same, for a picture at `scale` times its fitted size: zoomed in, a drag pans and never closes, and a drag
  /// whose fingers `pinched` on the way was a pinch, not a swipe.
  public static func closes(dragHeight height: CGFloat, scale: CGFloat, pinched: Bool) -> Bool {
    scale <= 1 && !pinched && closes(dragHeight: height)
  }
}
