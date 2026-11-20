//  A label's letters as single pen strokes, the way a hand writes them, not the outline around each letter (#895):
//  Igor, 2026-11-14, "don't use that outline view, just use like normal arial". The shapes are the Hershey fonts
//  (BoardLetteringGlyphs.swift); this reads them and says which characters they write.

import Foundation

public enum BoardLettering {
  /// One character's strokes in Hershey units: y down, the baseline at `baseline`, a capital `capHeight` tall; drawn
  /// from `left` to `right`, which is also its advance.
  struct Glyph {
    let left: CGFloat
    let right: CGFloat
    let strokes: [[CGPoint]]
    var advance: CGFloat { right - left }
  }

  /// Where a Hershey letter stands, in its units: the baseline's y, and a capital's height above it.
  static let baseline: CGFloat = 9
  static let capHeight: CGFloat = 21

  static let printFace: [Glyph] = printGlyphs.map { parse($0.joined()) }
  static let handFace: [Glyph] = handGlyphs.map { parse($0.joined()) }

  /// The written glyph for `character` in `face`; nil for one the fonts don't have (beyond the keyboard's ASCII).
  static func glyph(_ character: Character, face: WhiteboardTurn.Face) -> Glyph? {
    guard let code = character.asciiValue, (32...126).contains(code) else { return nil }
    return (face == .print ? printFace : handFace)[Int(code) - 32]
  }

  /// `text` with a model's typography in its plain keyboard form, so curly quotes, dashes and an ellipsis are written
  /// rather than traced.
  static func plain(_ text: String) -> String {
    var out = ""
    for character in text {
      switch character {
      case "\u{2018}", "\u{2019}", "\u{201A}", "\u{2032}": out.append("'")
      case "\u{201C}", "\u{201D}", "\u{201E}", "\u{2033}": out.append("\"")
      case "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2212}": out.append("-")
      case "\u{2026}": out.append("...")
      case "\u{00A0}", "\u{2009}", "\u{202F}": out.append(" ")
      default: out.append(character)
      }
    }
    return out
  }

  /// One entry of the James Hurt format: the left and right bearing, then points, each two characters offset from
  /// "R", with " R" lifting the pen.
  static func parse(_ data: String) -> Glyph {
    let codes = Array(data.utf8).map { CGFloat(Int($0) - 82) }
    guard codes.count >= 2 else { return Glyph(left: 0, right: 0, strokes: []) }
    var strokes: [[CGPoint]] = []
    var current: [CGPoint] = []
    let raw = Array(data.utf8)
    var i = 2
    while i + 1 < codes.count {
      if raw[i] == UInt8(ascii: " ") {
        if current.count > 1 { strokes.append(current) }
        current = []
      } else {
        current.append(CGPoint(x: codes[i], y: codes[i + 1]))
      }
      i += 2
    }
    if current.count > 1 { strokes.append(current) }
    return Glyph(left: codes[0], right: codes[1], strokes: strokes)
  }
}
