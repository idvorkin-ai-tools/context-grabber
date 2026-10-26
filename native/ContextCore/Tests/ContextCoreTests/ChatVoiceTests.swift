import XCTest

@testable import ContextCore

/// Speaking a message in Chat (#448, story 303): the clip's request and what comes back into the draft.
final class ChatVoiceTests: XCTestCase {
  func testTheRequestIsTheCockpitsModelWithTheKeyOnlyInTheHeader() {
    let audio = Data([1, 2, 3])
    let request = ChatVoice.request(audio: audio, key: " secret-key \n")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.httpBody, audio)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token secret-key")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "audio/mp4")
    XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "GrabberNative")
    let built = ChatVoice.request(audio: audio, key: "k", userAgent: "GrabberNative/abc1234")
    XCTAssertEqual(built.value(forHTTPHeaderField: "User-Agent"), "GrabberNative/abc1234")
    let url = request.url!.absoluteString
    XCTAssertTrue(
      url.hasPrefix("https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&punctuate=true&keyterm="), url)
    XCTAssertTrue(url.contains("&keyterm=Larry"), url)
    XCTAssertTrue(url.contains("&keyterm=Kettlebility"), url)
    XCTAssertFalse(url.contains("secret"), "the key never rides in the address")
  }

  func testATranscriptIsReadAndTrimmed() throws {
    let body = Data(
      #"{"metadata":{},"results":{"channels":[{"alternatives":[{"transcript":" Hey Larry, call Tori. ","confidence":0.98}]}]}}"#
        .utf8)
    XCTAssertEqual(try ChatVoice.transcript(status: 200, body: body), "Hey Larry, call Tori.")
  }

  func testSilenceIsAnEmptyTranscriptAndLeavesTheDraftUnchanged() throws {
    let silent = Data(#"{"results":{"channels":[{"alternatives":[{"transcript":""}]}]}}"#.utf8)
    let words = try ChatVoice.transcript(status: 200, body: silent)
    XCTAssertEqual(words, "")
    XCTAssertEqual(ChatVoice.draft("typed so far", adding: words), "typed so far")
    XCTAssertEqual(ChatVoice.draft("", adding: "  \n"), "")
    let none = Data(#"{"results":{"channels":[{"alternatives":[]}]}}"#.utf8)
    XCTAssertEqual(try ChatVoice.transcript(status: 200, body: none), "")
  }

  func testTheWordsGoAfterWhatWasTyped() {
    XCTAssertEqual(ChatVoice.draft("", adding: "Hello."), "Hello.")
    XCTAssertEqual(ChatVoice.draft("Look:", adding: "Hello."), "Look: Hello.")
    XCTAssertEqual(ChatVoice.draft("Look:\n", adding: "Hello."), "Look:\nHello.")
    XCTAssertEqual(ChatVoice.draft("Look: ", adding: "Hello."), "Look: Hello.")
  }

  func testARefusalCarriesDeepgramsReasonAndPointsAtTheKey() {
    let body = Data(#"{"err_code":"INVALID_AUTH","err_msg":"Invalid credentials.","request_id":"x"}"#.utf8)
    XCTAssertThrowsError(try ChatVoice.transcript(status: 401, body: body)) { error in
      let failure = error as? ChatVoice.Failure
      XCTAssertEqual(failure?.status, 401)
      XCTAssertEqual(
        failure?.message,
        "Deepgram answered 401 INVALID_AUTH: Invalid credentials. Check the key in Settings → Voice in Chat.")
    }
    XCTAssertThrowsError(try ChatVoice.transcript(status: 502, body: Data("<html>".utf8))) { error in
      XCTAssertEqual((error as? ChatVoice.Failure)?.message, "Deepgram answered 502")
    }
  }

  func testAnAnswerWithoutResultsIsAFailureNotSilence() {
    XCTAssertThrowsError(try ChatVoice.transcript(status: 200, body: Data("{}".utf8)))
    XCTAssertThrowsError(try ChatVoice.transcript(status: 200, body: Data("not json".utf8)))
  }

  func testAFailureReadsAsItsMessageWhereverItIsShown() {
    let error: Error = ChatVoice.Failure(status: 0, message: "the recorder would not start")
    XCTAssertEqual(error.localizedDescription, "the recorder would not start")
  }

  func testTheClock() {
    XCTAssertEqual(ChatVoice.elapsed(0), "0:00")
    XCTAssertEqual(ChatVoice.elapsed(7.9), "0:07")
    XCTAssertEqual(ChatVoice.elapsed(72), "1:12")
    XCTAssertEqual(ChatVoice.elapsed(-3), "0:00")
  }
}
