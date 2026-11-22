import XCTest

@testable import ContextCore

/// Speaking a message in Chat (#448, story 303): the mic's five-minute limit and its clock.
final class ChatVoiceTests: XCTestCase {
  func testTheClock() {
    XCTAssertEqual(ChatVoice.elapsed(0), "0:00")
    XCTAssertEqual(ChatVoice.elapsed(7.9), "0:07")
    XCTAssertEqual(ChatVoice.elapsed(72), "1:12")
    XCTAssertEqual(ChatVoice.elapsed(-3), "0:00")
  }

  func testARecordingIsCappedAtFiveMinutes() {
    XCTAssertEqual(ChatVoice.limit, 300)
    XCTAssertEqual(ChatVoice.elapsed(ChatVoice.limit), "5:00")
    XCTAssertEqual(ChatVoice.cappedLine, "Stopped at 5 minutes.")
  }
}

final class ChatVoiceClockTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_000_000)

  func testARecordingStartsAndStopsWithItsSeconds() {
    var clock = ChatVoiceClock()
    XCTAssertEqual(
      clock.listening(true, at: t0), .started(recording: 1, capAt: t0.addingTimeInterval(ChatVoice.limit)))
    XCTAssertEqual(clock.listening(true, at: t0.addingTimeInterval(1)), .none, "the same state again")
    XCTAssertEqual(clock.listening(false, at: t0.addingTimeInterval(12.34)), .stopped(seconds: 12.3))
    XCTAssertEqual(clock.listening(false, at: t0.addingTimeInterval(13)), .none)
  }

  func testTheTimerCapsARecordingThatRanTheLimit() {
    var clock = ChatVoiceClock()
    _ = clock.listening(true, at: t0)
    XCTAssertTrue(clock.shouldCap(recording: 1, at: t0.addingTimeInterval(ChatVoice.limit)))
  }

  func testTheTimerDoesNotSurviveAStop() {
    var clock = ChatVoiceClock()
    _ = clock.listening(true, at: t0)
    _ = clock.listening(false, at: t0.addingTimeInterval(30))
    XCTAssertFalse(clock.shouldCap(recording: 1, at: t0.addingTimeInterval(ChatVoice.limit)))
  }

  func testALaterRecordingIsNotCappedByAnEarlierOnesTimer() {
    var clock = ChatVoiceClock()
    _ = clock.listening(true, at: t0)
    _ = clock.listening(false, at: t0.addingTimeInterval(30))
    let later = t0.addingTimeInterval(200)
    XCTAssertEqual(
      clock.listening(true, at: later), .started(recording: 2, capAt: later.addingTimeInterval(ChatVoice.limit)))
    // The first recording's timer fires at t0 + 5:00, 100 s into the second.
    XCTAssertFalse(clock.shouldCap(recording: 1, at: t0.addingTimeInterval(ChatVoice.limit)))
    XCTAssertFalse(clock.shouldCap(recording: 2, at: t0.addingTimeInterval(ChatVoice.limit)), "only 100 s in")
    XCTAssertTrue(clock.shouldCap(recording: 2, at: later.addingTimeInterval(ChatVoice.limit)))
  }
}

final class ChatVoiceWordsTests: XCTestCase {
  func testAThreadsWordsAreNeverTakenByAnother() {
    var words = ChatVoiceWords()
    words.heard("typed, then spoken", thread: "A")
    XCTAssertNil(words.take(thread: "B"))
    XCTAssertEqual(words.take(thread: "A"), "typed, then spoken")
    XCTAssertNil(words.take(thread: "A"), "taken once")
  }

  func testTheLatestDraftWinsAndARepeatIsStillNew() {
    var words = ChatVoiceWords()
    words.heard("hello", thread: "A")
    let first = words.latest
    words.heard("hello", thread: "A")
    XCTAssertNotEqual(words.latest, first, "the same text again is a new hand-off")
    words.heard("hello there", thread: "A")
    XCTAssertEqual(words.take(thread: "A"), "hello there")
  }
}

/// The voice button beside the + (#637, stories 500 and 505).
final class ChatNewChatVoiceTests: XCTestCase {
  func testTheVoiceButtonRecordsOnceSoABarComingBackDoesNotRecordAgain() {
    var ask = ChatNewChatVoice()
    ask.open(voice: true)
    XCTAssertTrue(ask.take())
    XCTAssertFalse(ask.take())
  }

  func testThePlusNeverRecordsEvenRightAfterAnUntakenVoiceTap() {
    var ask = ChatNewChatVoice()
    XCTAssertFalse(ask.take())
    ask.open(voice: true)
    ask.open(voice: false)
    XCTAssertFalse(ask.take())
  }
}

/// The screen kept awake while a chat recording runs (#1165, story 303).
final class ChatVoiceAwakeTests: XCTestCase {
  func testAutoLockIsHeldFromTheStartToTheStop() {
    var awake = ChatVoiceAwake()
    XCTAssertEqual(awake.recording(true, flagNow: false), true, "on at the start")
    XCTAssertNil(awake.recording(true, flagNow: true), "the same state again writes nothing")
    XCTAssertEqual(awake.recording(false, flagNow: true), false, "off at the stop")
    XCTAssertNil(awake.recording(false, flagNow: false), "a second stop writes nothing")
    XCTAssertFalse(awake.holding)
  }

  func testEachRecordingHoldsItAgain() {
    var awake = ChatVoiceAwake()
    XCTAssertEqual(awake.recording(true, flagNow: false), true)
    XCTAssertEqual(awake.recording(false, flagNow: true), false)
    XCTAssertEqual(awake.recording(true, flagNow: false), true)
    XCTAssertEqual(awake.recording(false, flagNow: true), false)
  }

  func testNeverOnWithoutAStart() {
    var awake = ChatVoiceAwake()
    XCTAssertNil(awake.recording(false, flagNow: false))
    XCTAssertNil(awake.recording(false, flagNow: true), "someone else's hold is left alone")
  }

  func testAHoldSomeoneElseSetIsLeftOnAtTheStop() {
    var awake = ChatVoiceAwake()
    XCTAssertNil(awake.recording(true, flagNow: true), "the Gym Timer already holds it")
    XCTAssertNil(awake.recording(false, flagNow: true), "so the chat's stop does not clear it")
    XCTAssertEqual(awake.recording(true, flagNow: false), true, "the next recording on its own holds it")
    XCTAssertEqual(awake.recording(false, flagNow: true), false)
  }
}
