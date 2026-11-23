//  What part of the board the picture of Larry's turn showed, for story 765's repeat tap: a tap with the same pages on
//  screen and nothing new sends nothing. A board opened again while its Send waited in the outbox knows it from the
//  waiting picture itself (story 1192, bead context-grabber-kocz).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum WhiteboardLarryFrame: Equatable, Sendable {
  /// The part of the board on screen when the picture was taken.
  case rect(CGRect)
  /// The waiting picture: its frame is that part with the folds it drew open in it.
  case picture(WhiteboardPicture)

  /// The pages on screen, `rect`, aren't the ones the picture showed.
  public func moved(to rect: CGRect) -> Bool {
    switch self {
    case .rect(let shown): return rect != shown
    case .picture(let picture): return !picture.shows(rect)
    }
  }
}

extension WhiteboardPicture {
  /// The picture was taken of `rect` on the board: its frame is `rect` as the folds it drew open stretch it. Worked
  /// forward, as the picture was, so the sums are the same and the match exact.
  public func shows(_ rect: CGRect) -> Bool {
    let taken = folds.map { $0.toPicture(rect) } ?? rect
    return taken == CGRect(x: frame.x, y: frame.y, width: frame.w, height: frame.h)
  }
}
