//  Rewording a kept text (spec 2026-11-17-whiteboard-reword-and-live-snap-design.md, stories 940–942; the web board's
//  `rewordText` in cockpit assets/ink/board.mjs): what the edited words mean, how wide the text wraps, and where its new
//  lines go. Board points throughout. PaperKit, the field and the undo stay in the app.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif
#if canImport(CoreText)
  import CoreText
#endif

public enum BoardReword {
  /// The most a text holds: the board's paste cap, as on the web board.
  public static let maxText = BoardToText.maxText
  /// The web board's text width (`PASTE_W`): a text wraps no narrower, unless the page is.
  public static let webWidth: CGFloat = 480
  /// No text wraps narrower than this, however near the page's edge it starts (the web board's To text floor).
  public static let narrowest: CGFloat = 160
  /// Board points kept clear of the page's right edge.
  public static let air: CGFloat = 20
  /// Undo's names for the two changes.
  public static let undoName = "Edit text"
  public static let deleteName = "Delete text"

  public enum Outcome: Equatable, Sendable {
    /// The same words: no change and no undo step.
    case unchanged
    /// Emptied: the text goes.
    case delete
    /// New words, trimmed and capped.
    case reword(String)
  }

  /// What done with `edited` in the field means for a text that read `old`.
  public static func outcome(old: String, edited: String) -> Outcome {
    let trimmed = String(edited.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxText))
    if trimmed.isEmpty { return .delete }
    return trimmed == old.trimmingCharacters(in: .whitespacesAndNewlines) ? .unchanged : .reword(trimmed)
  }

  /// The width the words wrap to: the wider of the text's own (`box`) and the web board's, never past the page's right
  /// edge less `air`, never under `narrowest`.
  public static func width(box: CGRect, pageRight: CGFloat) -> CGFloat {
    let room = pageRight - air - box.minX
    return max(narrowest, min(max(box.width, webWidth), room))
  }

  #if canImport(CoreText)
    /// `text` as the rows it draws in: its own line breaks kept, each wrapped by word to `width` in `face` at letter
    /// height `size`, a word longer than a row broken. Empty lines between paragraphs stay; trailing ones go. Measured
    /// in `lettering`, the text's own (#950).
    public static func rows(
      _ text: String, width: CGFloat, size: CGFloat, face: WhiteboardTurn.Face,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> [String] {
      let fits = { (s: String) in measure(s, size: size, face: face, lettering: lettering) <= width }
      var out: [String] = []
      for para in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
        var line = ""
        for var word in para.split(whereSeparator: \.isWhitespace).map(String.init) {
          while !fits(word), word.count > 1 {
            if !line.isEmpty {
              out.append(line)
              line = ""
            }
            var n = word.count - 1
            while n > 1, !fits(String(word.prefix(n))) { n -= 1 }
            out.append(String(word.prefix(n)))
            word = String(word.dropFirst(n))
          }
          if line.isEmpty {
            line = word
          } else if fits(line + " " + word) {
            line += " " + word
          } else {
            out.append(line)
            line = word
          }
        }
        out.append(line)
      }
      while out.count > 1, out.last?.isEmpty == true { out.removeLast() }
      return out
    }

    /// A row's width in `face` at letter height `size`.
    public static func measure(
      _ text: String, size: CGFloat, face: WhiteboardTurn.Face, lettering: WhiteboardTurn.LetterStyle = .single
    ) -> CGFloat {
      WhiteboardTurn.lettered(text, topLeft: .zero, height: size, face: face, lettering: lettering).width
    }

    /// Where a text's lines start, from where its letters are: the box its glyphs drew (`box`) less how far the letters
    /// of `text` sit inside their own lines, laid out as the board lays a text.
    public static func topLeft(
      of text: String, size: CGFloat, face: WhiteboardTurn.Face, box: CGRect,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> CGPoint {
      let rows = text.split(whereSeparator: \.isNewline).map(String.init)
      let own = bounds(
        lines(rows, topLeft: .zero, size: size, face: face, lettering: lettering).flatMap {
          WhiteboardTurn.lines($0, frame: .zero, scale: 1)
        }
      )
      guard !own.isNull, !box.isNull else { return box.isNull ? .zero : box.origin }
      return CGPoint(x: box.minX - own.minX, y: box.minY - own.minY)
    }

    /// The marks that draw `rows` from `topLeft`, a row every `BoardToText.leading` letter heights, as To text lays them.
    public static func lines(
      _ rows: [String], topLeft: CGPoint, size: CGFloat, face: WhiteboardTurn.Face,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> [WhiteboardTurn.Shape] {
      rows.enumerated().compactMap { i, row in
        guard !row.isEmpty else { return nil }
        let top = topLeft.y + CGFloat(i) * size * BoardToText.leading
        return WhiteboardTurn.Shape(
          kind: .text, points: [CGPoint(x: topLeft.x, y: top)], text: row, size: size, face: face, lettering: lettering)
      }
    }

    static func bounds(_ lines: [[CGPoint]]) -> CGRect {
      let points = lines.joined()
      guard let first = points.first else { return .null }
      return points.reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
  #endif
}
