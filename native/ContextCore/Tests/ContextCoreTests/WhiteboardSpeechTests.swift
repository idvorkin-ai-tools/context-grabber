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

  func testARevisionOfSentWordsGivesOnlyTheWholeNewWords() {
    var speech = WhiteboardSpeech()
    speech.heard("draw to boxes")
    XCTAssertEqual(speech.takeNew(), "draw to boxes")
    speech.heard("draw two boxes and label it")
    XCTAssertEqual(speech.takeNew(), "and label it")
    speech = WhiteboardSpeech()
    speech.heard("draw a circle here")
    _ = speech.takeNew()
    speech.heard("draw a circle there now")
    XCTAssertEqual(speech.takeNew(), "now")
  }

  func testAFinalResultThatOnlyRevisesSendsNothing() {
    var speech = WhiteboardSpeech()
    speech.heard("draw to boxes")
    _ = speech.takeNew()
    speech.heard("draw two boxes")
    XCTAssertNil(speech.takeNew())
  }

  func testTheContextNamesTheBoardAndWhatWasSaid() {
    XCTAssertEqual(WhiteboardSpeech.context(title: "Plan", said: nil), "Plan")
    XCTAssertEqual(WhiteboardSpeech.context(title: "Plan", said: "mark the dip"), "Plan\nIgor just said: mark the dip")
  }

  /// Story 1305 (Igor, 2026-11-24: "Keep a silence send, only after 5 s or more").
  func testFiveSecondsOfSilenceSendsTheWaitingWordsAndLessSendsNothing() {
    var speech = WhiteboardSpeech()
    speech.heard("what about tuesday")
    XCTAssertEqual(WhiteboardSpeech.silenceSendMs, 5000)
    XCTAssertFalse(speech.silenceSends(silentMs: 4999))
    XCTAssertTrue(speech.silenceSends(silentMs: 5000))
  }

  func testSilenceAfterWordsAlreadyTakenSendsNothing() {
    var speech = WhiteboardSpeech()
    XCTAssertFalse(speech.silenceSends(silentMs: 60_000))
    speech.heard("what about tuesday")
    _ = speech.takeNew()
    XCTAssertFalse(speech.silenceSends(silentMs: 60_000))
  }
}
