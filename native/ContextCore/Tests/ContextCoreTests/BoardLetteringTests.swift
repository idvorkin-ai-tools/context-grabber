import Foundation
import XCTest

@testable import ContextCore

/// #895: a label's letters are written in single pen strokes, not traced as outlines.
final class BoardLetteringTests: XCTestCase {
  func testEveryKeyboardCharacterHasAGlyphInBothFaces() {
    XCTAssertEqual(BoardLettering.printFace.count, 95)
    XCTAssertEqual(BoardLettering.handFace.count, 95)
    for code in 33...126 {
      let character = Character(UnicodeScalar(UInt8(code)))
      for face in [WhiteboardTurn.Face.print, .hand] {
        let glyph = BoardLettering.glyph(character, face: face)
        XCTAssertFalse(glyph?.strokes.isEmpty ?? true, "\(character) in \(face)")
        XCTAssertGreaterThan(glyph?.advance ?? 0, 0, "\(character) in \(face)")
      }
    }
    XCTAssertEqual(BoardLettering.glyph(" ", face: .print)?.strokes.count, 0)
    XCTAssertNil(BoardLettering.glyph("é", face: .print))
  }

  /// An outline goes round a stem and closes on itself; a written stem is one open line.
  func testAnLIsOneOpenStrokeAndAnHIsThree() throws {
    let l = try XCTUnwrap(BoardLettering.glyph("l", face: .print))
    XCTAssertEqual(l.strokes.count, 1)
    XCTAssertNotEqual(l.strokes[0].first, l.strokes[0].last)
    XCTAssertEqual(BoardLettering.glyph("H", face: .print)?.strokes.count, 3)
  }

  func testAModelsTypographyIsWrittenInItsKeyboardForm() {
    XCTAssertEqual(BoardLettering.plain("it\u{2019}s \u{201C}ok\u{201D} \u{2014} so\u{2026}"), "it's \"ok\" - so...")
    XCTAssertEqual(BoardLettering.plain("café →"), "café →")
  }

  #if canImport(CoreText)
    func testCurlyPunctuationDrawsAsItsPlainForm() {
      let curly = WhiteboardTurn.glyphLines("it\u{2019}s\u{2026}", topLeft: .zero, height: 20)
      let plain = WhiteboardTurn.glyphLines("it's...", topLeft: .zero, height: 20)
      XCTAssertEqual(curly, plain)
    }

    /// A label is written, and takes about the room its outlines did: as tall, and within a few letters as wide.
    func testAWrittenLabelTakesTheRoomItsOutlinesDid() {
      let text = "Hi! I see you"
      let written = WhiteboardMarkChoice.bounds(WhiteboardTurn.glyphLines(text, topLeft: .zero, height: 40))
      let traced = WhiteboardMarkChoice.bounds(WhiteboardTurn.outlineLines(text, topLeft: .zero, height: 40))
      XCTAssertEqual(written.minY, traced.minY, accuracy: 1.5, "capitals as tall")
      XCTAssertEqual(written.maxY, traced.maxY, accuracy: 1.5, "on the same baseline")
      XCTAssertEqual(written.width, traced.width, accuracy: traced.width * 0.25)
    }

    /// A character the written letters lack keeps its outline, after the written ones, so nothing in a label is lost.
    func testACharacterTheLettersLackIsTracedInPlace() {
      let written = WhiteboardTurn.lettered("ab", topLeft: .zero, height: 20, face: .print)
      let mixed = WhiteboardTurn.glyphLines("abé", topLeft: .zero, height: 20)
      XCTAssertGreaterThan(mixed.count, written.lines.count)
      let accent = mixed.dropFirst(written.lines.count).joined()
      XCTAssertGreaterThanOrEqual(accent.map(\.x).min() ?? 0, written.width - 1)
    }

    func testRewordMeasuresTheWrittenLetters() {
      let measured = BoardReword.measure("word", size: 20, face: .print)
      XCTAssertEqual(measured, WhiteboardTurn.lettered("word", topLeft: .zero, height: 20, face: .print).width)
      let drawn = WhiteboardMarkChoice.bounds(WhiteboardTurn.glyphLines("word", topLeft: .zero, height: 20))
      XCTAssertLessThanOrEqual(drawn.maxX, measured)
    }

    func testTheHandFaceIsWrittenToo() {
      let hand = WhiteboardTurn.glyphLines("hi", topLeft: .zero, height: 20, face: .hand)
      XCTAssertFalse(hand.isEmpty)
      XCTAssertNotEqual(hand, WhiteboardTurn.glyphLines("hi", topLeft: .zero, height: 20, face: .print))
    }
  #endif
}
