//  Handwriting to text (spec 2026-11-16-whiteboard-to-text-and-snap-design.md, stories 920–922): a picture of the
//  selected ink goes to the Cockpit's `POST /ink/to-text` (cockpit ink_text.py, as the web board's "To text" sends it),
//  and the words it reads come back to take the ink's place as a kept text. Here: the picture's crop, the request, what
//  the answer means, and where the words go. PaperKit and the drawing stay in the app.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardToText {
  /// The most a text holds, the Cockpit's `MAX_TEXT` (the board's paste cap): more and the ink stays.
  public static let maxText = 500
  /// Board points of white round the ink, and picture pixels per board point, as the web board crops it.
  public static let pad: CGFloat = 12
  public static let pixelsPerPoint: CGFloat = 2
  /// The Cockpit gives the model 90 s; a little more, so its own timeout is the one that answers.
  public static let timeout: TimeInterval = 100
  /// Undo's name for it, and the log's.
  public static let undoName = "To text"

  /// What the picture covers, in board points: the ink's box with `pad` round it, never above or left of the board.
  public static func crop(ink: CGRect) -> CGRect {
    let left = max(0, ink.minX - pad)
    let top = max(0, ink.minY - pad)
    return CGRect(x: left, y: top, width: ink.maxX + pad - left, height: ink.maxY + pad - top)
  }

  public enum Answer: Equatable, Sendable {
    /// The words, trimmed, at most `maxText` characters.
    case text(String)
    /// The Cockpit read no writing there.
    case noWriting
    /// More than one text holds: the ink stays.
    case tooLong
    /// The Cockpit away, refusing or failing: `status` nil when there was no answer at all.
    case failed(status: Int?, reason: String)
  }

  /// What the Cockpit's answer means: `{ok: true, text, too_long, via, ...}` or `{ok: false, error}`.
  public static func answer(status: Int?, body: Data?, error: String? = nil) -> Answer {
    guard let status else { return .failed(status: nil, reason: error ?? "no answer from the Cockpit") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard status == 200, let json, json["ok"] as? Bool == true else {
      let reason = (json?["error"] as? String) ?? "HTTP \(status)"
      return .failed(status: status, reason: reason)
    }
    if json["too_long"] as? Bool == true { return .tooLong }
    let text = (json["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return .noWriting }
    return text.count > maxText ? .tooLong : .text(text)
  }

  /// One typed line, where it goes: its top-left in board points and its letters' height.
  public struct Line: Equatable, Sendable {
    public var text: String
    public var topLeft: CGPoint
    public var size: CGFloat

    /// The mark that draws it, in the plain lettering, placed with a frame at the board's origin and a scale of 1.
    public var shape: WhiteboardTurn.Shape {
      WhiteboardTurn.Shape(kind: .text, points: [topLeft], text: text, size: size, face: .print)
    }
  }

  /// The letters' height range, in board points: never smaller than reads, never bigger than a header.
  public static let sizes: ClosedRange<CGFloat> = 14...48
  /// A typed line's height for its letters' height.
  public static let leading: CGFloat = 1.35

  /// The words where the ink was: one typed line per line read, from the ink's top-left, its letters sized so the lines
  /// take about the ink's height.
  public static func lines(_ text: String, ink: CGRect) -> [Line] {
    let rows = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    guard !rows.isEmpty, !ink.isNull else { return [] }
    let fitted = ink.height / CGFloat(rows.count) / leading
    let size = min(max(fitted, sizes.lowerBound), sizes.upperBound).rounded()
    return rows.enumerated().map { i, row in
      let top = (ink.minY + CGFloat(i) * size * leading).rounded()
      return Line(text: row, topLeft: CGPoint(x: ink.minX.rounded(), y: top), size: size)
    }
  }

  /// The whole text as the kept text remembers it: its lines, joined.
  public static func words(_ lines: [Line]) -> String { lines.map(\.text).joined(separator: "\n") }
}
