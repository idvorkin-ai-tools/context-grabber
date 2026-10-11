import XCTest

@testable import ContextCore

final class CallWatchdogTests: XCTestCase {
  func testMicIsStalledOnlyWhenArmedUnpausedAndQuietForTheWholeWindow() {
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: false, paused: false, armedAt: 0, lastBufferAt: 0), .idle)
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: true, paused: true, armedAt: 0, lastBufferAt: 0), .idle)
    // a fresh tap gets the full grace from arming
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: true, paused: false, armedAt: 9_000, lastBufferAt: 0), .ok)
    XCTAssertEqual(
      CallWatchdog.mic(now: 10_500, armed: true, paused: false, armedAt: 9_000, lastBufferAt: 0), .stalled)
    XCTAssertEqual(
      CallWatchdog.mic(now: 10_500, armed: true, paused: false, armedAt: 1_000, lastBufferAt: 9_100), .ok)
  }

  func testOutputIsStalledWhenAudioIsDueRecentlyScheduledAndTheClockSitsStill() {
    func v(_ now: Double, _ t: Double, _ prev: Double, _ prevAt: Double, _ head: Double, _ sched: Double)
      -> CallWatchdog.Verdict
    {
      CallWatchdog.output(
        now: now, currentTime: t, previousTime: prev, previousCheckAt: prevAt, playhead: head, lastScheduledAt: sched)
    }
    XCTAssertEqual(v(5000, 2, 2, 4500, 2.01, 4900), .idle)  // nothing due
    XCTAssertEqual(v(5000, 2, 2, 3000, 3, 2000), .idle)  // nothing scheduled lately: a silent line
    XCTAssertEqual(v(5000, 2.5, 2, 4900, 3, 4900), .ok)  // the clock moved
    XCTAssertEqual(v(5000, 2, 2, 4500, 3, 4900), .ok)  // still, but not for long
    XCTAssertEqual(v(5000, 2, 2, 4000, 3, 4900), .stalled)
  }

  func testAudioIsAbsentOnlyWhileTextKeepsComingWithoutAudio() {
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 0, lastAudioAt: 0))
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 9_000, lastAudioAt: 8_000))
    XCTAssertTrue(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 9_000, lastAudioAt: 4_000))
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 20_000, lastTextAt: 9_000, lastAudioAt: 0))  // Tony went quiet
  }

  func testPlaybackIsDescribedInOneClause() {
    XCTAssertEqual(PlaybackStats.describe(nil), "no playback")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 1.5, playedS: 1.2, clockRunning: true, pendingS: 0)),
      "played 1.2s of 1.5s")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 0, playedS: 0, clockRunning: false, pendingS: 0.4)),
      "played 0.0s of 0.0s (0.4s held, clock not running)")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 0, playedS: 0, clockRunning: false, pendingS: 0)),
      "played 0.0s of 0.0s (nothing to play yet)")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 2, playedS: 1, clockRunning: false, pendingS: 0)),
      "played 1.0s of 2.0s (clock not running)")
  }
}

final class CallEventLogTests: XCTestCase {
  func testLinesAreStampedSortedAndSeparatedBetweenCalls() {
    let log = CallEventLog()
    log.add("call_start", t: 1200, fields: ["backend": "eleven", "voice": "tony"])
    log.add("call_ready", t: 3400, fields: ["out_rate": 16000.0, "session": "s 1"])
    log.add("call_ended", t: 9000, fields: ["reason": "stopped", "badly": false])
    log.add("call_start", t: 12000, fields: ["backend": "gemini", "voice": "tony"])
    XCTAssertEqual(
      log.lines,
      [
        "+1.2s call_start backend=eleven voice=tony",
        "+3.4s call_ready out_rate=16000 session=\"s 1\"",
        "+9.0s call_ended badly=false reason=stopped",
        CallEventLog.separator,
        "+12.0s call_start backend=gemini voice=tony",
      ])
    XCTAssertEqual(log.currentCall.count, 1)
    XCTAssertEqual(
      log.render(header: [("build", "abc (main)"), ("problem", "")]).components(separatedBy: "\n").prefix(3),
      ["build: abc (main)", "---", "+1.2s call_start backend=eleven voice=tony"])
  }

  func testKeepsTheNewestWhenFull() {
    let log = CallEventLog(limit: 3)
    for i in 0..<5 { log.add("call_x", t: i, fields: [:]) }
    XCTAssertEqual(log.events.map { $0.t }, [2, 3, 4])
  }

  private func events(_ list: [(String, [String: Any])]) -> [CallEvent] {
    list.map { CallEvent(t: 0, type: $0.0, fields: $0.1) }
  }

  func testTroubleIsWhatTheLogSays() {
    let clean = events([
      ("call_start", [:]), ("call_ready", [:]), ("call_mic", ["action": "open", "ok": true]),
      ("call_problem", ["problem": ""]), ("call_ended", ["reason": "stopped", "badly": false]),
    ])
    XCTAssertFalse(CallEventLog.hadTrouble(clean))
    XCTAssertTrue(CallEventLog.hadTrouble(clean + events([("call_heal", ["action": "rearm_mic"])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_problem", ["problem": "the microphone stopped delivering"])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_ended", ["reason": "connection lost", "badly": true])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_audio", ["action": "engine_start", "ok": false])])))
    XCTAssertFalse(CallEventLog.hadTrouble(events([("timer_cue", ["ok": false])])))  // not the call's
  }
}
