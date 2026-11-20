//  #950 (stories 1044–1046): a board's text in a real font, still ink: the per-board choice, a mark's or a text of
//  Larry's own choice, and the font's outlines as the strokes that draw it.

import Foundation
import XCTest

@testable import ContextCore

final class BoardRealFontTests: XCTestCase {
  private func fresh() -> BoardLetteringChoice {
    let suite = "board-lettering-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return BoardLetteringChoice(defaults: defaults)
  }

  // MARK: The board's choice

  func testABoardWithNothingChosenLettersInSingleStrokes() {
    XCTAssertEqual(fresh().choice("old"), .single)
  }

  func testAChoiceIsTheBoardsOwnAndIsForgottenWithIt() {
    let choice = fresh()
    choice.set(.font, board: "a")
    XCTAssertEqual(choice.choice("a"), .font)
    XCTAssertEqual(choice.choice("b"), .single, "another board's choice is its own")
    choice.forget("a")
    XCTAssertEqual(choice.choice("a"), .single)
  }

  func testTheMenusWords() {
    XCTAssertEqual(WhiteboardTurn.LetterStyle.allCases.map(\.name), ["Single strokes", "Real font"])
  }

  // MARK: What a mark or a text asks for

  func testALabelCanNameItsLettering() {
    let font = WhiteboardTurn.shape(
      ["kind": "text", "points": [[1, 2]], "text": "hi", "lettering": "font"], lettering: { _, _ in true })
    XCTAssertEqual(font?.lettering, .font)
    let none = WhiteboardTurn.shape(["kind": "text", "points": [[1, 2]], "text": "hi"], lettering: { _, _ in true })
    XCTAssertNil(none?.lettering, "none named: the board's")
    let unknown = WhiteboardTurn.shape(
      ["kind": "text", "points": [[1, 2]], "text": "hi", "lettering": "gothic"], lettering: { _, _ in true })
    XCTAssertNotNil(unknown, "an unknown lettering never drops the label")
    XCTAssertNil(unknown?.lettering)
  }

  func testAGhostLabelStrokeCarriesItsLettering() {
    let shape = WhiteboardTurn.anyShape(
      ["kind": "label", "x": 10.0, "y": 40.0, "text": "hi", "lettering": "font"], lettering: { _, _ in true })
    XCTAssertEqual(shape?.lettering, .font)
  }

  func testLarrysTextCanNameItsLettering() throws {
    let batch = try XCTUnwrap(
      BoardOps.batch(
        [
          "board": "b", "base_rev": 0, "label": "l",
          "list": [
            ["op": "add_text", "id": "t1", "x": 1, "y": 2, "text": "hi", "lettering": "font"],
            ["op": "add_text", "id": "t2", "x": 1, "y": 2, "text": "hi"],
          ],
        ], key: "k", source: "web"))
    let texts = batch.ops.compactMap { op -> BoardOps.Text? in
      if case .addText(let text) = op { return text }
      return nil
    }
    XCTAssertEqual(texts.map(\.lettering), [.font, nil])
    XCTAssertEqual(texts[0].shape.lettering, .font)
    XCTAssertEqual(texts[0].wire["lettering"] as? String, "font")
    XCTAssertNil(texts[1].wire["lettering"])
  }

  /// A kept text keeps its lettering through a save; one saved before the choice reads as single strokes.
  func testAKeptTextKeepsItsLetteringThroughASave() throws {
    let text = BoardText(id: "t", t: 1, text: "hi", font: .plain, size: 18, color: "#000000", lettering: .font)
    let back = try JSONDecoder().decode(BoardText.self, from: JSONEncoder().encode(text))
    XCTAssertEqual(back.lettering, .font)
    let old = try JSONDecoder().decode(
      BoardText.self,
      from: Data(##"{"id":"t","t":1,"text":"hi","font":"plain","size":18,"color":"#000000"}"##.utf8))
    XCTAssertNil(old.lettering)
  }

  /// The strokes Larry is sent name a text exactly as before: the Cockpit refuses any other field.
  func testTheStrokesLarryIsSentAreUnchanged() {
    let text = BoardText(id: "t", t: 1, text: "hi", font: .plain, size: 18, color: "#000000", lettering: .font)
    let placed = PlacedText(text: text, x: 0, y: 0, w: 10, h: 10)
    XCTAssertEqual(
      Set(placed.wire.keys), ["kind", "id", "text", "font", "x", "y", "w", "h", "color", "t"])
  }

  #if canImport(CoreText)
    // MARK: The font's outlines as ink

    /// In the real font an H is its outline, one closed loop, not the three strokes a pen writes it in.
    func testARealFontHIsItsClosedOutline() throws {
      let single = WhiteboardTurn.glyphLines("H", topLeft: .zero, height: 40)
      let font = WhiteboardTurn.glyphLines("H", topLeft: .zero, height: 40, lettering: .font)
      XCTAssertEqual(single.count, 3)
      XCTAssertEqual(font.count, 1)
      let loop = try XCTUnwrap(font.first)
      XCTAssertEqual(loop.first, loop.last, "an outline closes on itself")
      XCTAssertEqual(font, WhiteboardTurn.outlineLines("H", topLeft: .zero, height: 40), "the font's own outline")
    }

    /// A label in the real font stands where a written one would: capitals as tall, on the same baseline.
    func testARealFontLabelStandsWhereAWrittenOneWould() {
      let text = "Hi! I see you"
      let written = WhiteboardMarkChoice.bounds(WhiteboardTurn.glyphLines(text, topLeft: .zero, height: 40))
      let font = WhiteboardMarkChoice.bounds(
        WhiteboardTurn.glyphLines(text, topLeft: .zero, height: 40, lettering: .font))
      XCTAssertEqual(font.minY, written.minY, accuracy: 1.5)
      XCTAssertEqual(font.maxY, written.maxY, accuracy: 1.5)
      XCTAssertEqual(font.width, written.width, accuracy: written.width * 0.25)
    }

    /// A shape's own lettering wins over the board's; one that names none takes the board's.
    func testAShapesOwnLetteringWinsOverTheBoards() {
      let asked = WhiteboardTurn.Shape(kind: .text, points: [.zero], text: "H", size: 40, lettering: .single)
      let none = WhiteboardTurn.Shape(kind: .text, points: [.zero], text: "H", size: 40)
      XCTAssertEqual(WhiteboardTurn.lines(asked, frame: .zero, scale: 1, lettering: .font).count, 3)
      XCTAssertEqual(WhiteboardTurn.lines(none, frame: .zero, scale: 1, lettering: .font).count, 1)
      XCTAssertEqual(WhiteboardTurn.lines(none, frame: .zero, scale: 1).count, 3, "no board lettering: single strokes")
    }

    /// The hand face's real font is Noteworthy's outlines, not print's.
    func testTheHandFaceHasItsOwnFont() {
      let print = WhiteboardTurn.glyphLines("hi", topLeft: .zero, height: 30, lettering: .font)
      let hand = WhiteboardTurn.glyphLines("hi", topLeft: .zero, height: 30, face: .hand, lettering: .font)
      XCTAssertFalse(hand.isEmpty)
      XCTAssertNotEqual(hand, print)
      XCTAssertEqual(hand, WhiteboardTurn.outlineLines("hi", topLeft: .zero, height: 30, face: .hand))
    }

    /// An emoji still draws nothing, so its label has no letters in either lettering.
    func testAnEmojiDrawsNothingInTheRealFont() {
      XCTAssertTrue(WhiteboardTurn.glyphLines("🙂", topLeft: .zero, height: 30, lettering: .font).isEmpty)
    }

    /// A paste on a real-font board: HI is the font's two outlines, wrapped and placed by the same rules.
    func testAPasteInTheRealFont() {
      let visible = CGRect(x: 0, y: 0, width: 800, height: 600)
      let single = WhiteboardPaste.layout("HI", visible: visible, height: 24)
      let font = WhiteboardPaste.layout("HI", visible: visible, height: 24, lettering: .font)
      XCTAssertEqual(single.lines.count, 4)
      XCTAssertEqual(font.lines.count, 2)
      let a = WhiteboardMarkChoice.bounds(single.lines)
      let b = WhiteboardMarkChoice.bounds(font.lines)
      XCTAssertEqual(b.midX, visible.midX, accuracy: 1, "centred as a written paste is")
      XCTAssertEqual(b.height, a.height, accuracy: 2)
    }

    /// A paste wraps by the font's own widths.
    func testAPasteWrapsByTheFontsWidths() {
      let width = BoardReword.measure("WWW WWW", size: 24, face: .print, lettering: .font) - 1
      XCTAssertEqual(
        WhiteboardPaste.wrapped("WWW WWW", width: width, height: 24, lettering: .font), ["WWW ", "WWW"])
    }

    /// A reword measures and redraws in the text's own lettering.
    func testARewordMeasuresAndDrawsInTheTextsLettering() {
      let measured = BoardReword.measure("word", size: 20, face: .print, lettering: .font)
      let drawn = WhiteboardMarkChoice.bounds(
        WhiteboardTurn.glyphLines("word", topLeft: .zero, height: 20, lettering: .font))
      XCTAssertLessThanOrEqual(drawn.maxX, measured + 0.5)
      let shapes = BoardReword.lines(["HI"], topLeft: .zero, size: 20, face: .print, lettering: .font)
      XCTAssertEqual(shapes.map(\.lettering), [.font])
      XCTAssertEqual(shapes.flatMap { WhiteboardTurn.lines($0, frame: .zero, scale: 1) }.count, 2)
    }
  #endif
}
