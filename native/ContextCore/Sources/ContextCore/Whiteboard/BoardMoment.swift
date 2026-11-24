//  The moment a stroke was made, in unix milliseconds: once, for every rule that names a stroke by it (stroke ids sent
//  to Larry, the moments of ink that is Larry's or Claude's, the reword's and the selection label's strokes, the kept
//  ink's look). Ids and remembered moments truncate: every one on a board was made this way, so a rounded one would
//  miss them a millisecond in two. The kept ink's look alone rounds (`nearest`), because it matches the strokes
//  PaperKit holds against the ones the board made, and those sit on whole milliseconds.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardMoment {
  /// `date` in unix milliseconds, truncated.
  public static func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

  /// `date` in unix milliseconds, rounded to the nearest. A kept mark's dates are whole milliseconds, and a date
  /// PaperKit hands back can read a hair under one, which truncation would put a millisecond early.
  public static func nearestMs(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }
}

#if canImport(PencilKit)
  import PencilKit

  extension BoardMoment {
    /// When `stroke` was made, in unix milliseconds: the moment the board knows it by.
    public static func of(_ stroke: PKStroke) -> Int64 { ms(stroke.path.creationDate) }

    /// When `stroke` was made, rounded to the nearest millisecond: how the kept ink's look matches the strokes PaperKit
    /// holds against the ones the board made.
    public static func nearest(_ stroke: PKStroke) -> Int64 { nearestMs(stroke.path.creationDate) }
  }
#endif
