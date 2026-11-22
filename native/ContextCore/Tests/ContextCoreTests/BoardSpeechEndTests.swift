import XCTest

@testable import ContextCore

/// Story 1118, bead context-grabber-u1yy: the timings are the iPad's 2026-11-22 log (board ead78e80), where a 1 s
/// silence sent each of these cut.
final class BoardSpeechEndTests: XCTestCase {
  func testASentenceGoesAfterAboutOneAndAHalfSeconds() {
    XCTAssertEqual(BoardSpeechEnd.wait(after: "Draw a box around this.").ms, 1500)
    XCTAssertEqual(BoardSpeechEnd.wait(after: "what does that mean?").why, .sentence)
    XCTAssertFalse(BoardSpeechEnd.finished("Draw a box.", silentMs: 1400))
    XCTAssertTrue(BoardSpeechEnd.finished("Draw a box.", silentMs: 1500))
  }

  func testAPhraseWithNoSentenceEndWaitsLonger() {
    XCTAssertEqual(BoardSpeechEnd.wait(after: "OK when I drop text").why, .open)
    // Log: the words went on 2.4 s after "OK when I drop text".
    XCTAssertFalse(BoardSpeechEnd.finished("OK when I drop text", silentMs: 2400))
    // Log: the 31 then 42 character pair, about 1.2 s apart.
    XCTAssertFalse(BoardSpeechEnd.finished("mark the dip", silentMs: 1200))
    XCTAssertTrue(BoardSpeechEnd.finished("OK when I drop text", silentMs: 3000))
  }

  func testAHangingLastWordWaitsTheBound() {
    // Log: the words went on about 4.5 s after "I see a chip that says".
    XCTAssertEqual(BoardSpeechEnd.wait(after: "I see a chip that says").why, .dangling)
    XCTAssertFalse(BoardSpeechEnd.finished("I see a chip that says", silentMs: 4500))
    XCTAssertTrue(BoardSpeechEnd.finished("I see a chip that says", silentMs: 5000))
    XCTAssertEqual(BoardSpeechEnd.wait(after: "and the,").why, .dangling)
  }

  func testNothingWaitsPastTheBound() {
    for words in ["", "the", "draw it.", "OK when I drop text", "I'm"] {
      XCTAssertLessThanOrEqual(BoardSpeechEnd.wait(after: words).ms, BoardSpeechEnd.danglingMs, words)
    }
  }

  func testARepeatedCallbackIsNotNewWords() {
    // Log: a callback 632 ms after the cut carried the same 22 characters; it must not restart the silence.
    var speech = WhiteboardSpeech()
    XCTAssertTrue(speech.heard("I see a chip that says"))
    XCTAssertFalse(speech.heard("I see a chip that says"))
    XCTAssertEqual(speech.pending, "I see a chip that says")
    XCTAssertTrue(speech.heard("I see a chip that says your board what does that mean"))
    XCTAssertEqual(speech.takeNew(), "I see a chip that says your board what does that mean")
    XCTAssertNil(speech.pending)
  }
}
