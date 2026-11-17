//  A hold in the board's left margin, by finger or Pencil (spec 2026-11-16-whiteboard-board-ops-design.md, *Press and
//  hold (#918)*, stories 858, 930–933): whether a touch there became the room handle or the menu, or why not. Igor
//  reached for the margin with the Pencil and it only drew (build 6e2ee969). Pure: the board judges a Pencil stroke
//  from its path, and every try goes in the session log with its verdict.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardMarginHold {
  public enum Tool: String, Sendable { case finger, pencil }

  /// How far a Pencil may drift, board points, before half a second has passed and it is still a hold: his two long
  /// holds on the iPad drifted past 10 (Larry, 2026-11-17). Once the hold has fired, any drift is the drag.
  public static let pencilStill: CGFloat = 12

  public enum Verdict: Equatable, Sendable {
    /// Held still long enough: the handle, dragged `dy` board points by the time it lifted (about none: the menu).
    case hold(dy: CGFloat)
    /// It moved `by` points, `after` seconds in, before it had held long enough: it draws (or pans).
    case moved(after: Double, by: CGFloat)
    /// It lifted after `seconds`, still, before it had held long enough.
    case tooShort(seconds: Double)
    /// It didn't go down in the margin.
    case notInMargin

    /// The log's word for it.
    public var reason: String {
      switch self {
      case .hold: "hold"
      case .moved: "moved"
      case .tooShort: "too_short"
      case .notInMargin: "not_in_margin"
      }
    }

    /// A drag this far opens or closes room; less is the menu.
    public var opensRoom: Bool {
      if case .hold(let dy) = self { return abs(dy) >= BoardRoom.line / 2 }
      return false
    }
  }

  /// A Pencil stroke's path in board points, each point's time in seconds since the stroke began: a hold when it went
  /// down in the margin and stayed within `still` of there for `holdAfter`.
  public static func pencil(
    _ path: [(point: CGPoint, time: Double)], holdAfter: Double = BoardMargin.holdAfter, still: CGFloat = pencilStill
  ) -> Verdict {
    guard let start = path.first, let end = path.last else { return .notInMargin }
    guard start.point.x >= 0, start.point.x < BoardMargin.width else { return .notInMargin }
    // Only the first half second counts: after it, the Pencil is the handle and moving it is the drag.
    if let away = path.first(where: { $0.time - start.time < holdAfter && distance($0.point, start.point) > still }) {
      return .moved(after: away.time - start.time, by: distance(away.point, start.point))
    }
    let seconds = end.time - start.time
    guard seconds >= holdAfter else { return .tooShort(seconds: seconds) }
    return .hold(dy: end.point.y - start.point.y)
  }

  /// A finger's try, judged when it lifts, for the log: how long it was down, how far it went (screen points), and
  /// whether the hold recogniser fired. `not_seen` is a still, long touch the recogniser never had: PaperKit took it.
  public static func finger(seconds: Double, travel: CGFloat, recognized: Bool) -> String {
    if recognized { return "hold" }
    if travel > BoardMargin.dragAfter { return "moved" }
    if seconds < BoardMargin.holdAfter { return "too_short" }
    return "not_seen"
  }

  private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
