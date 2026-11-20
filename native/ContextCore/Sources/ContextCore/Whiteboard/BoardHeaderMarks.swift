//  Where a header's ▾ sits (#1004, stories 1040, 1041; spec 2026-11-19-whiteboard-ink-headers-design.md, *Seeing
//  the headers*): one spot at the margin's left edge for every header, standing on its line's baseline, over the
//  ink, and a margin tap within 22 points of its middle is on it. The ▾ in the margin's middle sat on the very # that
//  made the header (the iPad, 2026-11-20: a # at x 6–33 hid its ▾ at x 32). Pure: the boxes, in board points.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOutline {
  /// The ▾'s square, board points: as tall as a line's small letters and a little more.
  public static let headerMarkSize: CGFloat = 22
  /// Its left edge, from the column's: the same for every header, whatever the line's indent.
  public static let headerMarkLeft: CGFloat = 4
  /// A margin tap this far above or below the ▾'s middle is on its header: 44 points top to bottom.
  public static let headerMarkReach: CGFloat = 22

  /// A header's mark in the margin: ▾ open, ▸ and its lines folded.
  public struct HeaderMark: Equatable, Sendable {
    public var header: String
    public var folded: Bool
    public var text: String
    /// The line's baseline, which the mark stands on.
    public var baseline: CGFloat
    /// The mark, board points: its bottom on the baseline, its left at `headerMarkLeft`.
    public var box: CGRect
  }

  /// The header's baseline: the middle of its writing's bottoms, so a g's tail or a #'s long bar doesn't drag it down.
  /// Its underline is left out; a line of nothing but long flat strokes (a simulator's "writing") stands on them.
  public func baseline(_ header: BoardHeader) -> CGFloat? {
    let at = index
    let own = header.ids.compactMap { at[$0] }.filter { !strokes[$0].hidden }
    guard !own.isEmpty else { return nil }
    let words = own.filter { !Self.isUnderline(strokes[$0]) }
    let bottoms = (words.isEmpty ? own : words).map { strokes[$0].bounds.maxY }.sorted()
    return bottoms[bottoms.count / 2]
  }

  /// The mark of each header that shows, folded or open.
  public var headerMarks: [HeaderMark] {
    headers.compactMap(headerMark)
  }

  public func headerMark(_ header: BoardHeader) -> HeaderMark? {
    guard shows(header), let baseline = baseline(header) else { return nil }
    let folded = isFolded(header)
    let text = folded ? "▸ \(header.fold?.lines ?? 0)" : "▾"
    // "▸ 12" is wider than the ▾'s square: about 9 points a character, inside the 64-point margin.
    let width = folded ? max(Self.headerMarkSize, CGFloat(text.count) * 9 + 8) : Self.headerMarkSize
    let box = CGRect(
      x: Self.headerMarkLeft, y: baseline - Self.headerMarkSize, width: width, height: Self.headerMarkSize)
    return HeaderMark(header: header.id, folded: folded, text: text, baseline: baseline, box: box)
  }

  /// A margin tap at `y` is on the mark: within `headerMarkReach` of its middle.
  func onMark(_ header: BoardHeader, y: CGFloat) -> Bool {
    guard let mark = headerMark(header) else { return false }
    return abs(y - mark.box.midY) <= Self.headerMarkReach
  }
}
