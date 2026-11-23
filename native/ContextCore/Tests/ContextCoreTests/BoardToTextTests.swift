import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Stories 920–922: the selected ink's picture to the Cockpit's `POST /ink/to-text` (cockpit ink_text.py), its answer,
/// and where the words go.
final class BoardToTextTests: XCTestCase {
  private func json(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) }

  // MARK: Story 920: the request, the words and where they go

  func testTheCropIsTheInkWithAirRoundItNeverOffTheBoard() {
    XCTAssertEqual(
      BoardToText.crop(ink: CGRect(x: 100, y: 200, width: 50, height: 30)),
      CGRect(x: 88, y: 188, width: 74, height: 54))
    XCTAssertEqual(
      BoardToText.crop(ink: CGRect(x: 4, y: 0, width: 50, height: 30)), CGRect(x: 0, y: 0, width: 66, height: 42))
  }

  func testTheWordsAreTheAnswer() {
    let body = json([
      "ok": true, "text": "  buy milk\nand eggs \n", "too_long": false, "advice": [], "via": "anthropic",
    ])
    XCTAssertEqual(BoardToText.answer(status: 200, body: body), .text("buy milk\nand eggs"))
  }

  func testOneTypedLinePerLineReadAtTheInksTopLeftSizedToIt() {
    let ink = CGRect(x: 120.4, y: 300, width: 300, height: 108)
    let lines = BoardToText.lines("buy milk\n\n  and eggs ", ink: ink)
    XCTAssertEqual(lines.map(\.text), ["buy milk", "and eggs"])
    XCTAssertEqual(lines[0].size, 40, "two lines in 108 points")
    XCTAssertEqual(lines[0].topLeft, CGPoint(x: 120, y: 300))
    XCTAssertEqual(lines[1].topLeft, CGPoint(x: 120, y: 354))
    XCTAssertEqual(lines[0].shape.face, .print)
    XCTAssertEqual(lines[0].shape.kind, .text)
    XCTAssertEqual(BoardToText.words(lines), "buy milk\nand eggs")
    // A tiny scribble still reads; a tall one isn't a header.
    XCTAssertEqual(BoardToText.lines("a", ink: CGRect(x: 0, y: 0, width: 10, height: 5))[0].size, 14)
    XCTAssertEqual(BoardToText.lines("a", ink: CGRect(x: 0, y: 0, width: 10, height: 500))[0].size, 48)
    XCTAssertTrue(BoardToText.lines(" \n ", ink: ink).isEmpty)
  }

  // MARK: Story 921: a failure leaves the ink and says why

  func testAFailureSaysTheCockpitsReason() {
    XCTAssertEqual(
      BoardToText.answer(status: 502, body: json(["ok": false, "error": "the model declined to read this"])),
      .failed(status: 502, reason: "the model declined to read this"))
    XCTAssertEqual(BoardToText.answer(status: 404, body: Data("nope".utf8)), .failed(status: 404, reason: "HTTP 404"))
    XCTAssertEqual(
      BoardToText.answer(status: 200, body: json(["ok": false, "error": "png is not a PNG"])),
      .failed(status: 200, reason: "png is not a PNG"))
    XCTAssertEqual(
      BoardToText.answer(status: nil, body: nil, error: "The request timed out."),
      .failed(status: nil, reason: "The request timed out."))
  }

  // MARK: Story 922: no writing, or too much

  func testNoWritingOrTooMuchLeavesTheInk() {
    XCTAssertEqual(BoardToText.answer(status: 200, body: json(["ok": true, "text": " \n"])), .noWriting)
    XCTAssertEqual(BoardToText.answer(status: 200, body: json(["ok": true])), .noWriting)
    XCTAssertEqual(
      BoardToText.answer(
        status: 200, body: json(["ok": true, "text": String(repeating: "a", count: 500), "too_long": true])),
      .tooLong)
    XCTAssertEqual(
      BoardToText.answer(status: 200, body: json(["ok": true, "text": String(repeating: "a", count: 501)])), .tooLong)
    XCTAssertEqual(
      BoardToText.answer(status: 200, body: json(["ok": true, "text": String(repeating: "a", count: 500)])),
      .text(String(repeating: "a", count: 500)))
  }
}
