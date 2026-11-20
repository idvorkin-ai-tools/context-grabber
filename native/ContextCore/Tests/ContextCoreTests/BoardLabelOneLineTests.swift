import Foundation
import XCTest

@testable import ContextCore

/// #624: Larry's label "Hi! I see you" (9 pixels in a 165-pixel-wide picture of a tall board, a scale of about 0.21,
/// so letters about 43 board points tall) was seen on the iPad as two fragments, "H'I ‥" and "I. see you". The
/// conversion from his label to strokes was suspected. It isn't the cause: the label comes out as one unbroken line
/// of every letter, before #895 (as outlines) and after it (written), and the fragments were kept strokes moved apart
/// afterwards (the issue's 2026-11-03 comment). This pins the conversion so it can't be the cause later.
final class BoardLabelOneLineTests: XCTestCase {
  #if canImport(CoreText)
    private let scale: CGFloat = 0.21
    private let text = "Hi! I see you"

    private func label() throws -> [[CGPoint]] {
      let shape = #"{"kind": "label", "text": "\#(text)", "x": 10, "y": 40, "size": 9}"#
      guard
        case .shapes(let shapes) = WhiteboardTurn.answer(
          status: 200, body: Data(#"{"ok": true, "strokes": [\#(shape)]}"#.utf8))
      else { throw XCTSkip("no shapes") }
      let frame = CGRect(x: 0, y: 0, width: 165 / scale, height: 2048 / scale)
      return WhiteboardTurn.lines(try XCTUnwrap(shapes.first), frame: frame, scale: scale)
    }

    /// Every letter is there: written single strokes, counted from the letters' shapes (H three, i and ! a stem and a
    /// dot, I one, s, e and o one each, y and u two).
    func testTheLabelHasEveryLettersStrokes() throws {
      XCTAssertEqual(try label().count, 3 + 2 + 2 + 1 + 1 + 1 + 1 + 2 + 1 + 2)
    }

    /// One row: nothing sits a line below, as a wrapped or broken label would.
    func testTheLabelIsOneRow() throws {
      let points = try label().joined()
      let letters = 9 / scale
      let top = try XCTUnwrap(points.map(\.y).min())
      let bottom = try XCTUnwrap(points.map(\.y).max())
      XCTAssertLessThanOrEqual(bottom - top, letters * 1.3, "one row of \(letters)-point letters")
    }

    /// Left to right with no hole wider than two spaces (a space and the bearings either side): the words aren't split
    /// apart along the row.
    func testTheLettersRunOnWithNoHoleWiderThanTwoSpaces() throws {
      let spans = try label().map { line in (line.map(\.x).min() ?? 0, line.map(\.x).max() ?? 0) }.sorted {
        $0.0 < $1.0
      }
      let space = WhiteboardTurn.lettered(" ", topLeft: .zero, height: 9 / scale, face: .print).width
      var reach = try XCTUnwrap(spans.first).1
      for span in spans.dropFirst() {
        XCTAssertLessThanOrEqual(span.0 - reach, space * 2, "a hole at x \(reach)")
        reach = max(reach, span.1)
      }
    }

    /// Kept, the strokes PencilKit gets stay in that row.
    func testKeptInkStaysInTheRow() throws {
      let lines = try label()
      let kept = lines.map { WhiteboardTurn.inkPoints($0) }.joined()
      let drawn = lines.joined()
      XCTAssertEqual(kept.map(\.y).min() ?? 0, drawn.map(\.y).min() ?? 0, accuracy: 0.01)
      XCTAssertEqual(kept.map(\.y).max() ?? 0, drawn.map(\.y).max() ?? 0, accuracy: 0.01)
    }
  #endif
}
