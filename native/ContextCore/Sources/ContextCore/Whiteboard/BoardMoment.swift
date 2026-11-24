//  The moment a stroke was made, in unix milliseconds: once, for every rule that names a stroke by it (stroke ids sent
//  to Larry, the moments of ink that is Larry's or Claude's, the reword's and the selection label's strokes, the kept
//  ink's look). Truncated, never rounded: every id and every remembered moment on a board was made this way, so a
//  rounded one would miss them a millisecond in two.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardMoment {
  /// `date` in unix milliseconds, truncated.
  public static func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
}

#if canImport(PencilKit)
  import PencilKit

  extension BoardMoment {
    /// When `stroke` was made, in unix milliseconds: the moment the board knows it by.
    public static func of(_ stroke: PKStroke) -> Int64 { ms(stroke.path.creationDate) }
  }
#endif
