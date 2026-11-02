import XCTest

@testable import ContextCore

final class WhiteboardSpeechTests: XCTestCase {
  func testOnlyTheNewWordsAreTakenAndOnlyOnce() {
    var speech = WhiteboardSpeech()
    XCTAssertNil(speech.takeNew())
    speech.heard("draw a box")
    XCTAssertEqual(speech.takeNew(), "draw a box")
    XCTAssertNil(speech.takeNew())
    speech.heard("draw a box around this")
    XCTAssertEqual(speech.takeNew(), "around this")
  }

  func testARecognizerThatRestartsShorterStillGivesItsNextWords() {
    var speech = WhiteboardSpeech()
    speech.heard("draw a box around this")
    _ = speech.takeNew()
    speech.heard("draw a box")
    XCTAssertNil(speech.takeNew())
    speech.heard("draw a box and label it")
    XCTAssertEqual(speech.takeNew(), "and label it")
  }

  func testTheContextNamesTheBoardAndWhatWasSaid() {
    XCTAssertEqual(WhiteboardSpeech.context(title: "Plan", said: nil), "Plan")
    XCTAssertEqual(WhiteboardSpeech.context(title: "Plan", said: "mark the dip"), "Plan\nIgor just said: mark the dip")
  }
}
