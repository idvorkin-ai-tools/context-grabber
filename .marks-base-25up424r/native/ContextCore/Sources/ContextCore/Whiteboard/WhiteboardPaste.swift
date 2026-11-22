//  Pasted text as ink lines (spec 2026-11-02-whiteboard-paste-design.md, stories 390, 392, 393): capped, wrapped to the
//  view, and placed in the middle of it.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
  import CoreText
#endif

// The letters are written in single strokes as Larry's labels are (#996), measured and drawn where there are fonts, so
// the whole layout is Apple-only (just test-linux leaves it out).
#if canImport(CoreText)
  public enum WhiteboardPaste {
    public static let maxCharacters = 500
    public static let maxLines = 40

    public struct Layout: Equatable, Sendable {
      /// The letters' strokes, in board points. Empty when nothing in the text can be written or traced.
      public var lines: [[CGPoint]]
      /// How much of the text landed, and how much there was, in characters.
      public var kept: Int
      public var total: Int

      public var cut: Bool { kept < total }

      /// What the board's bar says after this paste (stories 392, 393): nothing can be drawn, or how much was left off.
      public var note: String? {
        if lines.isEmpty { return "Nothing in that text can be drawn" }
        return cut ? "Pasted the first \(kept) of \(total.formatted()) characters" : nil
      }
    }

    /// The old canvas's fixed square. A board on paper has its own: a page wide, with no end below.
    public static let wholeBoard = CGRect(x: 0, y: 0, width: WhiteboardFrame.side, height: WhiteboardFrame.side)

    /// `text` as `height`-point letters written inside `visible` (board points), on `board`, in the board's
    /// `lettering` (#950).
    public static func layout(
      _ text: String, visible: CGRect, height: CGFloat, board: CGRect = wholeBoard,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> Layout {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      let (rows, kept) = rows(trimmed, width: visible.width * 0.8, height: height, lettering: lettering)
      var lines: [[CGPoint]] = []
      for (i, row) in rows.enumerated() {
        lines += WhiteboardTurn.glyphLines(
          row, topLeft: CGPoint(x: 0, y: CGFloat(i) * height * 1.25), height: height, lettering: lettering)
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
    private static func rows(
      _ text: String, width: CGFloat, height: CGFloat, lettering: WhiteboardTurn.LetterStyle
    ) -> (rows: [String], kept: Int) {
      let capped = text.prefix(maxCharacters)
      var rows: [String] = []
      var kept = 0
      for line in capped.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
        for row in wrapped(String(line), width: width, height: height, lettering: lettering) {
          guard rows.count < maxLines else { return (rows, kept) }
          rows.append(row)
          kept += row.count
        }
        kept += 1  // the line's end
      }
      return (rows, min(kept, capped.count))
    }

    /// `line` in rows no wider than `width` in the written letters, broken after a space where it can be and inside a
    /// word too long for a row alone. The rows together are the line, character for character, so the count of what
    /// landed holds.
    static func wrapped(
      _ line: String, width: CGFloat, height: CGFloat, lettering: WhiteboardTurn.LetterStyle = .single
    ) -> [String] {
      guard !line.isEmpty else { return [""] }
      let measure = { (s: String) in
        WhiteboardTurn.lettered(
          String(s.reversed().drop { $0 == " " }.reversed()), topLeft: .zero, height: height, face: .print,
          lettering: lettering
        )
        .width
      }
      // Each word with the spaces after it: a row breaks only between them.
      var words: [String] = []
      for character in line {
        if character != " ", let last = words.last, last.last == " " {
          words.append(String(character))
        } else if words.isEmpty {
          words.append(String(character))
        } else {
          words[words.count - 1].append(character)
        }
      }
      var rows: [String] = []
      var row = ""
      for word in words {
        if measure(row + word) <= width {
          row += word
          continue
        }
        if !row.isEmpty { rows.append(row) }
        row = ""
        // A word too wide for a row alone breaks between its letters.
        for character in word {
          if !row.isEmpty, measure(row + String(character)) > width {
            rows.append(row)
            row = ""
          }
          row.append(character)
        }
      }
      if !row.isEmpty { rows.append(row) }
      return rows
    }
  }
#endif
