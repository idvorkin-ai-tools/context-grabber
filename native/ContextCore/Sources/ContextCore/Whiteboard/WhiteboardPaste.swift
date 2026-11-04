//  Pasted text as ink lines (spec 2026-11-02-whiteboard-paste-design.md, stories 390, 392, 393): capped, wrapped to the
//  view, and placed in the middle of it.

import CoreGraphics
import CoreText
import Foundation

public enum WhiteboardPaste {
  public static let maxCharacters = 500
  public static let maxLines = 40

  public struct Layout: Equatable, Sendable {
    /// The outlines of the letters, in board points. Empty when nothing in the text has an outline.
    public var lines: [[CGPoint]]
    /// How much of the text landed, and how much there was, in characters.
    public var kept: Int
    public var total: Int

    public var cut: Bool { kept < total }
  }

  /// The old canvas's fixed square. A board on paper has its own: a page wide, with no end below.
  public static let wholeBoard = CGRect(x: 0, y: 0, width: WhiteboardFrame.side, height: WhiteboardFrame.side)

  /// `text` as outlines of `height`-point letters inside `visible` (board points), on `board`.
  public static func layout(
    _ text: String, visible: CGRect, height: CGFloat, board: CGRect = wholeBoard
  ) -> Layout {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let (rows, kept) = rows(trimmed, width: visible.width * 0.8, height: height)
    var lines: [[CGPoint]] = []
    for (i, row) in rows.enumerated() {
      lines += WhiteboardTurn.glyphLines(row, topLeft: CGPoint(x: 0, y: CGFloat(i) * height * 1.25), height: height)
    }
    let points = lines.joined()
    guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(), let minY = points.map(\.y).min(),
      let maxY = points.map(\.y).max()
    else { return Layout(lines: [], kept: kept, total: trimmed.count) }
    let (width, tall) = (maxX - minX, maxY - minY)
    // Centred; a block taller than the view starts at its top, so the first line shows.
    let x = visible.midX - width / 2
    let y = max(visible.midY - tall / 2, visible.minY + height)
    let onBoard = { (v: CGFloat, span: CGFloat, low: CGFloat, high: CGFloat) in
      min(max(v, low), max(high - span, low))
    }
    let dx = onBoard(x, width, board.minX, board.maxX) - minX
    let dy = onBoard(y, tall, board.minY, board.maxY) - minY
    return Layout(
      lines: lines.map { $0.map { CGPoint(x: $0.x + dx, y: $0.y + dy) } }, kept: kept, total: trimmed.count)
  }

  /// The rows to draw and how many characters of `text` they cover: the clipboard's own lines, wrapped, within the caps.
  private static func rows(_ text: String, width: CGFloat, height: CGFloat) -> (rows: [String], kept: Int) {
    let capped = text.prefix(maxCharacters)
    var rows: [String] = []
    var kept = 0
    for line in capped.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      for row in wrapped(String(line), width: width, height: height) {
        guard rows.count < maxLines else { return (rows, kept) }
        rows.append(row)
        kept += row.count
      }
      kept += 1  // the line's end
    }
    return (rows, min(kept, capped.count))
  }

  private static func wrapped(_ line: String, width: CGFloat, height: CGFloat) -> [String] {
    guard !line.isEmpty else { return [""] }
    let font = CTFontCreateWithName("Helvetica" as CFString, height, nil)
    let typesetter = CTTypesetterCreateWithAttributedString(
      NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    let units = line as NSString
    var rows: [String] = []
    var start = 0
    while start < units.length {
      let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, Double(width)))
      rows.append(units.substring(with: NSRange(location: start, length: count)))
      start += count
    }
    return rows
  }
}
