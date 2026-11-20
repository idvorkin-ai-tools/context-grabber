//  Where things land and where room opens, by the web board's rules (spec 2026-11-16-whiteboard-board-ops-design.md,
//  *Paste makes room*; the Cockpit's assets/ink/board.mjs, `rows`, `snapCut`, `blankBand`, `placeBlock`). Everything is
//  in board points over the boxes of what moves whole (`BoardOps.items`): a cut never splits one. Pure.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardRoom {
  /// One ruled line: room opens in whole lines.
  public static let line: CGFloat = 40
  /// A cut looks this far up and down for a clear line.
  public static let near: CGFloat = 80
  /// Half a line of air around anything that lands.
  public static let air: CGFloat = 20

  /// The vertical spans ink takes up, overlapping boxes merged, top down. Every y outside one is a clear line.
  public static func rows(_ ink: [CGRect]) -> [ClosedRange<CGFloat>] {
    var out: [ClosedRange<CGFloat>] = []
    for box in ink.filter({ !$0.isNull }).sorted(by: { $0.minY < $1.minY }) {
      if let last = out.last, box.minY <= last.upperBound {
        out[out.count - 1] = last.lowerBound...max(last.upperBound, box.maxY)
      } else {
        out.append(box.minY...box.maxY)
      }
    }
    return out
  }

  /// `y` snapped to a clear line: itself if clear; else the nearer edge of the row it falls in, the top only within
  /// `near`; else the row's bottom.
  public static func cut(_ ink: [CGRect], at y: CGFloat) -> CGFloat {
    guard let row = rows(ink).first(where: { y > $0.lowerBound && y < $0.upperBound }) else { return y }
    let up = y - row.lowerBound
    let down = row.upperBound - y
    return up < down && up <= near ? row.lowerBound : row.upperBound
  }

  /// The blank band a clear line sits in: the lowest ink above it and the highest below (nil with none below).
  public static func band(_ ink: [CGRect], at cut: CGFloat) -> (above: CGFloat, below: CGFloat?) {
    var above: CGFloat = 0
    var below: CGFloat?
    for box in ink where !box.isNull {
      if box.minY >= cut { below = min(below ?? box.minY, box.minY) } else { above = max(above, box.maxY) }
    }
    return (above, below)
  }

  /// How much blank paper can close at a clear line, in whole lines: never past the lowest ink above.
  public static func closable(_ ink: [CGRect], at cut: CGFloat) -> CGFloat {
    let (above, below) = band(ink, at: cut)
    guard let below else { return 0 }
    return max(0, ((below - max(above, 0)) / line).rounded(.down)) * line
  }

  /// Room by hand (story 858): `dy` rounded to whole lines at the clear line nearest `y`; up closes blank paper only.
  /// Nil when nothing would move.
  public static func byHand(_ ink: [CGRect], at y: CGFloat, dy: CGFloat) -> Push? {
    let at = cut(ink, at: y)
    var d = (dy / line).rounded() * line
    if d < 0 { d = -min(-d, closable(ink, at: at)) }
    return d == 0 ? nil : Push(cut: at, dy: d)
  }

  /// Room for ink dropped by hand at `block`, lifted from `from` (stories 973–975, 980): none when it sits on none of
  /// `ink` (touching an edge isn't sitting on it, nor is ink on the line it was lifted from); else, from the clear line
  /// nearest its top, what is below goes down by whole lines until the first of it is `air` under the block. `ink` is
  /// everything but what was dropped.
  public static func drop(_ block: CGRect, from: CGRect, among ink: [CGRect]) -> Push? {
    let others = ink.filter { !$0.isNull }
    let sitsOn = others.contains { box in
      guard box.maxY <= from.minY || box.minY >= from.maxY else { return false }
      let overlap = box.intersection(block)
      return !overlap.isNull && overlap.width > 0 && overlap.height > 0
    }
    guard sitsOn else { return nil }
    let at = cut(others, at: block.minY)
    guard let below = band(others, at: at).below else { return nil }
    let dy = max(0, ((block.maxY + air - below) / line).rounded(.up)) * line
    return dy > 0 ? Push(cut: at, dy: dy) : nil
  }

  /// Where a text of Larry's at `box` lands and the room it opens (#938, story 992), as a paste or a drop does: on clear
  /// paper, or only beside ink, where he put it and nothing moves. On ink: from the clear line nearest its top,
  /// everything below goes down by whole lines until it is `air` under the text. When that line is the bottom of a line
  /// of writing its top fell in, that line stays and the text lands just under it. `y` is its top.
  public static func text(_ box: CGRect, among ink: [CGRect]) -> (y: CGFloat, push: Push?) {
    let others = ink.filter { !$0.isNull }
    let sitsOn = others.contains { other in
      let overlap = other.intersection(box)
      return !overlap.isNull && overlap.width > 0 && overlap.height > 0
    }
    guard sitsOn else { return (box.minY, nil) }
    let at = cut(others, at: box.minY)
    let y = at > box.minY ? at + air / 2 : box.minY
    guard let below = band(others, at: at).below else { return (y, nil) }
    let dy = max(0, ((y + box.height + air - below) / line).rounded(.up)) * line
    return (y, dy > 0 ? Push(cut: at, dy: dy) : nil)
  }

  /// What a reply of Larry's needs when kept over ink Igor made after its picture (#894, stories 1004–1006).
  public struct Late: Equatable, Sendable {
    /// The room it opens, or nil when it sits on nothing newer than the picture.
    public var push: Push?
    /// How many things made after the picture its marks sit on.
    public var covered: Int
  }

  /// Room for Larry's marks at `marks`, kept over what Igor made after his picture: none unless a mark sits on some of
  /// `newer`; else, from the clear line at or above the top of the newer ink it sits on, everything below goes down by
  /// whole lines until the first of it is `air` under the lowest mark. The marks stay where he put them. `ink` is all
  /// that shows, `newer` among it.
  public static func late(_ marks: [CGRect], newer: [CGRect], among ink: [CGRect]) -> Late {
    let marks = marks.filter { !$0.isNull }
    let covered = newer.filter { box in marks.contains { sitsOn($0, box) } }
    guard let top = covered.map(\.minY).min(), let bottom = marks.map(\.maxY).max() else {
      return Late(push: nil, covered: 0)
    }
    // Up to the top of the line of writing it starts in, however far: below it, the newer ink would stay covered.
    let at = rows(ink).first { top > $0.lowerBound && top < $0.upperBound }?.lowerBound ?? top
    guard let below = band(ink, at: at).below else { return Late(push: nil, covered: covered.count) }
    let dy = max(0, ((bottom + air - below) / line).rounded(.up)) * line
    return Late(push: dy > 0 ? Push(cut: at, dy: dy) : nil, covered: covered.count)
  }

  /// `late` over the board's strokes: what moves whole is newer than the picture taken at `seen` (unix ms) when any of
  /// its strokes was made after it by Igor. A stroke whose making isn't known is taken as seen; one whose moment (unix
  /// ms, a millisecond either way, as a saved drawing reads it back) is in `theirs` was made by Larry or Claude (a mark
  /// of theirs kept, ink or a text of Larry's) and never makes room.
  public static func late(
    _ marks: [CGRect], seen: Int64, strokes: [BoardOps.Stroke], texts: [BoardText] = [],
    groups: [String: String] = [:], folds: [String: String] = [:], theirs: Set<Int64> = []
  ) -> Late {
    let shown = BoardOps.items(strokes: strokes, texts: texts, groups: groups, folds: folds).filter { !$0.hidden }
    let newer = shown.filter { item in
      item.members.contains { member in
        strokes[member].t.map { t in t > seen && ![t - 1, t, t + 1].contains(where: theirs.contains) } ?? false
      }
    }
    return late(marks, newer: newer.map(\.bounds), among: shown.map(\.bounds))
  }

  /// Overlapping by some area: touching an edge isn't sitting on it.
  private static func sitsOn(_ a: CGRect, _ b: CGRect) -> Bool {
    let overlap = a.intersection(b)
    return !overlap.isNull && overlap.width > 0 && overlap.height > 0
  }

  /// Room that opens at a clear line: everything at or below `cut` goes down `dy`.
  public struct Push: Equatable, Sendable {
    public var cut: CGFloat
    public var dy: CGFloat
  }

  public struct Landing: Equatable, Sendable {
    /// The block's top-left.
    public var origin: CGPoint
    /// The room opened for it, or nil when clear paper held it.
    public var push: Push?
  }

  /// Where a block of `size` lands: the clear patch in `view` nearest its middle that holds it whole with air round
  /// it, left of `pageWidth` and right of the margin; else room opened at the clear line nearest the view's middle,
  /// as much as the block needs beyond the blank paper already there, in whole lines.
  public static func place(
    _ size: CGSize, view: CGRect, ink: [CGRect], pageWidth: CGFloat = BoardPages.pageWidth
  ) -> Landing {
    let near = ink.filter { !$0.isNull }.map { $0.insetBy(dx: -air, dy: -air) }.filter { $0.intersects(view) }
    let left = max(view.minX, BoardMargin.width + air)
    let right = min(view.maxX, pageWidth) - air
    // ponytail: a grid search, its step widened on a big view so it stays near 60 x 60 tries; a sweep over the
    // boxes' edges is the upgrade if a dense board ever makes a paste slow.
    let step = max(air, max(view.width, view.height) / 60)
    var best: (origin: CGPoint, d: CGFloat)?
    var y = view.minY + air
    while y + size.height <= view.maxY - air {
      var x = left
      while x + size.width <= right {
        let box = CGRect(origin: CGPoint(x: x, y: y), size: size)
        if !near.contains(where: { $0.intersects(box) }) {
          let d = hypot(box.midX - view.midX, box.midY - view.midY)
          if best.map({ d < $0.d }) ?? true { best = (box.origin, d) }
        }
        x += step
      }
      y += step
    }
    if let best { return Landing(origin: best.origin, push: nil) }
    let at = cut(ink, at: view.midY)
    let (above, below) = band(ink, at: at)
    let already = below.map { $0 - above } ?? .infinity
    let needed = size.height + 2 * air
    let dy = max(0, ((needed - already) / line).rounded(.up)) * line
    return Landing(
      origin: CGPoint(x: BoardMargin.width + air, y: above + air), push: dy > 0 ? Push(cut: at, dy: dy) : nil)
  }
}
