import XCTest

@testable import ContextCore

/// #582, story 829: a mic refused while the app is not in front holds the call for the app instead of healing.
final class CallHoldTests: XCTestCase {
  func testARefusalHoldsOnlyWhenTheAppIsNotInFront() {
    XCTAssertTrue(CallHold.holds(appState: "background"))
    XCTAssertTrue(CallHold.holds(appState: "inactive"))
    XCTAssertFalse(CallHold.holds(appState: "active"))
  }

  func testComingForwardStartsTheMicUntilTheCeiling() {
    XCTAssertEqual(CallHold.comeback(heldAt: 1000, now: 1000 + CallHold.ceilingMs - 1), .startMic)
    XCTAssertEqual(CallHold.comeback(heldAt: 1000, now: 1000 + CallHold.ceilingMs), .timedOut)
    XCTAssertEqual(CallHold.ceilingMs, 5 * 60_000)
  }

  func testTheNotificationSaysWhatTheDesignSays() {
    XCTAssertEqual(CallHold.notificationTitle, "Larry's call is waiting")
    XCTAssertEqual(CallHold.notificationBody, "Open Grabber to start the mic.")
    XCTAssertEqual(CallHold.waiting, "Open Grabber to start the mic")
  }

  private func events(_ list: [(String, [String: Any])]) -> [CallEvent] {
    list.map { CallEvent(t: 0, type: $0.0, fields: $0.1) }
  }

  private let refused: [(String, [String: Any])] = [
    ("call_audio", ["action": "playback_open", "ok": false, "app_state": "background"]),
    ("call_audio", ["action": "engine_start", "why": "mic", "ok": false, "app_state": "background"]),
    ("call_audio", ["action": "mic_arm", "ok": false, "app_state": "background"]),
  ]

  func testARefusalTheCallHeldForIsNotTrouble() {
    let start: [(String, [String: Any])] = [("call_start", [:]), ("call_ready", [:])]
    let held: [(String, [String: Any])] = [
      ("call_held", ["why": "background", "app_state": "background"]), ("call_resumed", ["held_ms": 4000.0]),
      ("call_audio", ["action": "engine_start", "why": "mic", "ok": true, "app_state": "active"]),
      ("call_mic", ["action": "open", "ok": true]), ("call_ended", ["reason": "stopped", "badly": false]),
    ]
    XCTAssertFalse(CallEventLog.hadTrouble(events(start + refused + held)))
    XCTAssertTrue(
      CallEventLog.hadTrouble(events(start + refused + [("call_ended", ["reason": "stopped", "badly": false])])),
      "refused with no hold: something went wrong")
  }

  func testARefusalWithTheAppInFrontIsTroubleEvenInAHeldCall() {
    let log: [(String, [String: Any])] = [
      ("call_start", [:]), ("call_held", ["why": "background", "app_state": "background"]),
      ("call_resumed", ["held_ms": 4000.0]),
      ("call_audio", ["action": "engine_start", "why": "mic", "ok": false, "app_state": "active"]),
      ("call_ended", ["reason": "stopped", "badly": false]),
    ]
    XCTAssertTrue(CallEventLog.hadTrouble(events(log)))
  }

  func testAHeldTimeoutIsNotTrouble() {
    let log: [(String, [String: Any])] = [
      ("call_start", [:]), ("call_held", ["why": "background", "app_state": "background"]),
      ("call_held_timeout", ["held_ms": CallHold.ceilingMs]),
      ("call_ended", ["reason": CallHold.timedOut, "badly": false]),
    ]
    XCTAssertFalse(CallEventLog.hadTrouble(events(refused + log)))
  }
}

final class CallSessionHoldTests: XCTestCase {
  private func heldCall() -> CallHarness {
    let t = CallHarness()
    t.appState = "background"
    t.audio.startMicError = Boom("avfaudio error 2003329396")
    t.goLive(.eleven, voice: .igor)
    return t
  }

  func testARefusedMicInTheBackgroundHoldsWithNoResetNoRedialAndNoProblem() {
    let t = heldCall()
    XCTAssertEqual(t.session.snapshot.state, .live)
    XCTAssertNotNil(t.session.snapshot.heldSince)
    XCTAssertTrue(t.session.snapshot.held)
    XCTAssertNil(t.session.snapshot.problem, "a hold is not a problem")
    XCTAssertEqual(t.last("call_held")?["why"] as? String, "background")
    XCTAssertEqual(t.last("call_held")?["app_state"] as? String, "background")
    XCTAssertEqual(t.notices, [.post])
    t.clock.advance(CallSession.firstFrameMs * 3)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertEqual(t.connects.count, 1)
    XCTAssertTrue(t.events.filter { $0.0 == "call_heal" }.isEmpty)
    XCTAssertFalse(t.eventTypes().contains("call_problem"))
  }

  func testAnInactiveAppHoldsToo() {
    let t = CallHarness()
    t.appState = "inactive"
    t.audio.startMicError = Boom("no input")
    t.goLive()
    XCTAssertTrue(t.session.snapshot.held)
  }

  func testComingForwardStartsTheMicTheNormalWayAndTheCallGoesOn() {
    let t = heldCall()
    t.clock.advance(4000)
    t.appState = "active"
    t.audio.startMicError = nil
    t.session.appBecameActive()
    XCTAssertFalse(t.session.snapshot.held)
    XCTAssertEqual(t.last("call_resumed")?["held_ms"] as? Double, 4000)
    XCTAssertEqual(t.audio.calls.filter { $0 == "startMic" }.count, 2)
    XCTAssertEqual(t.audio.openedAt, [24000, 24000], "playback opens again on the same start path")
    XCTAssertEqual(t.notices, [.post, .remove])
    t.audio.mic(value: 0.1)
    XCTAssertEqual(t.socket.binaries.count, 1)
    XCTAssertNil(t.session.snapshot.problem)
    t.clock.advance(CallHold.ceilingMs)
    XCTAssertEqual(t.session.snapshot.state, .live, "the ceiling is gone once the mic started")
  }

  func testARefusalAfterComingForwardIsARealFailureAndHeals() {
    let t = heldCall()
    t.appState = "active"
    t.session.appBecameActive()
    XCTAssertEqual(t.session.snapshot.problem, "microphone failed: avfaudio error 2003329396")
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 1)
  }

  func testTheNotificationGoesOncePerCall() {
    let t = heldCall()
    t.session.appBecameActive()  // still in the background as the start is tried: held again
    XCTAssertTrue(t.session.snapshot.held)
    XCTAssertEqual(t.notices, [.post, .remove])
    t.session.stop()
    XCTAssertEqual(t.notices, [.post, .remove, .remove])
  }

  func testTheCallEndsAsAHangUpAfterFiveMinutesAndNothingRedials() {
    let t = heldCall()
    t.clock.advance(CallHold.ceilingMs)
    XCTAssertEqual(t.session.snapshot.state, .ended)
    XCTAssertEqual(t.session.snapshot.endedReason, CallHold.timedOut)
    XCTAssertFalse(t.session.snapshot.endedBadly)
    XCTAssertFalse(t.session.snapshot.held)
    XCTAssertNotNil(t.last("call_held_timeout"))
    XCTAssertEqual(t.socket.types.suffix(2), ["stt_stop", "stop"])
    XCTAssertEqual(t.notices, [.post, .remove])
    t.clock.advance(CallHold.ceilingMs)
    XCTAssertEqual(t.connects.count, 1)
  }

  func testComingForwardAfterTheCeilingEndsTheCallInsteadOfStartingTheMic() {
    let t = heldCall()
    // A suspended app's timers run late: the wall clock moved, the ceiling's timer has not fired.
    t.clock.now += CallHold.ceilingMs + 1000
    t.appState = "active"
    t.session.appBecameActive()
    XCTAssertEqual(t.session.snapshot.endedReason, CallHold.timedOut)
    XCTAssertEqual(t.audio.calls.filter { $0 == "startMic" }.count, 1)
  }

  func testHangingUpWhileHeldTakesTheNotificationAway() {
    let t = heldCall()
    t.session.stop()
    XCTAssertEqual(t.notices, [.post, .remove])
    XCTAssertFalse(t.session.snapshot.held)
    t.clock.advance(CallHold.ceilingMs)
    XCTAssertNil(t.last("call_held_timeout"))
  }

  func testComingForwardWithNothingHeldDoesNothing() {
    let t = CallHarness()
    t.goLive()
    t.session.appBecameActive()
    XCTAssertEqual(t.audio.calls.filter { $0 == "startMic" }.count, 1)
    XCTAssertNil(t.last("call_resumed"))
  }

  // An opened mic with no buffer, and the app gone from the front: the reset and the redial would be refused too.
  func testNoFirstBufferInTheBackgroundHoldsInsteadOfResetting() {
    let t = CallHarness()
    t.goLive()
    t.appState = "background"
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertTrue(t.session.snapshot.held)
    XCTAssertEqual(t.notices, [.post])
    t.clock.advance(CallSession.firstFrameMs * 3)
    XCTAssertEqual(t.connects.count, 1)
  }

  func testANewCallStartsUnheld() {
    let t = heldCall()
    t.session.stop()
    t.appState = "active"
    t.audio.startMicError = nil
    t.nextSocket()
    t.session.start(.eleven)
    XCTAssertFalse(t.session.snapshot.held)
  }
}
