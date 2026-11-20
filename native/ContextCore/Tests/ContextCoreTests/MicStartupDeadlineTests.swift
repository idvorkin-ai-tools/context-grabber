//  #423, story 204: wait for Bluetooth startup without slowing a working built-in mic's heals.
import XCTest

@testable import ContextCore

final class MicStartupDeadlineTests: XCTestCase {
  func testDeadlineChoice() {
    XCTAssertEqual(MicStartupDeadline(bluetooth: true, sampleRate: 48000).ms, 10000)
    XCTAssertEqual(MicStartupDeadline(bluetooth: true).why, "bluetooth")
    XCTAssertEqual(MicStartupDeadline(sampleRate: 48000).ms, 1500)
    XCTAssertEqual(MicStartupDeadline(sampleRate: 48000).why, "ordinary_mic")
    XCTAssertEqual(MicStartupDeadline(sampleRate: 0).ms, 10000)
    XCTAssertEqual(MicStartupDeadline(sampleRate: 0).why, "zero_sample_rate")
  }

  func testBluetoothGetsTenSecondsBeforeResetAndAnotherWindowBeforeRedial() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true, sampleRate: 48000)
    t.goLive()
    XCTAssertEqual(t.last("call_mic")?["deadline_s"] as? Double, 10)
    XCTAssertEqual(t.last("call_mic")?["why"] as? String, "bluetooth")
    t.clock.advance(9999)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertEqual(t.connects.count, 1)
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1)
    XCTAssertEqual(t.last("call_heal")?["deadline_s"] as? Double, 10)
    t.clock.advance(9999)
    XCTAssertEqual(t.connects.count, 1)
    t.nextSocket()
    t.clock.advance(1)
    XCTAssertEqual(t.connects.count, 2)
  }

  func testAZeroRateAlsoWaitsAndAFirstBufferCancelsTheWatch() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(sampleRate: 0)
    t.goLive()
    XCTAssertEqual(t.last("call_mic")?["why"] as? String, "zero_sample_rate")
    t.clock.advance(9900)
    XCTAssertEqual(t.audio.restarts, 0)
    t.audio.mic(480, value: 0.3)
    t.socket.say(["type": "mic_ack", "token": 1])
    t.clock.advance(20000)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertEqual(t.connects.count, 1)
  }

  func testBluetoothAppearingBeforeResetExtendsFromTheOriginalOpenTime() {
    let t = CallHarness()
    t.goLive()
    t.clock.advance(1000)
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.clock.advance(500)
    XCTAssertEqual(t.audio.restarts, 0)
    t.audio.startupDeadline = MicStartupDeadline(sampleRate: 48000)
    t.clock.advance(8499)
    XCTAssertEqual(t.audio.restarts, 0)
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1)
  }

  func testAZeroRateAfterResetDefersRedialFromThatMicOpen() {
    let t = CallHarness()
    t.goLive()
    t.clock.advance(1500)
    XCTAssertEqual(t.audio.restarts, 1)
    t.audio.startupDeadline = MicStartupDeadline(sampleRate: 0)
    t.clock.advance(9999)
    XCTAssertEqual(t.connects.count, 1)
    t.nextSocket()
    t.clock.advance(1)
    XCTAssertEqual(t.connects.count, 2)
  }

  // #433, story 334: the audio rebuilt itself and reopened the mic 2 s into a Bluetooth window: ten more seconds.
  func testAnEngineReopenBeforeTheFirstBufferRestartsTheWindowFromThatReopen() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.goLive()
    t.clock.advance(2000)
    t.audio.onMicReopened?("route change")
    XCTAssertEqual(t.last("call_mic")?["action"] as? String, "first_frame_watch")
    XCTAssertEqual(t.last("call_mic")?["reopened"] as? String, "route change")
    XCTAssertEqual(t.last("call_mic")?["deadline_s"] as? Double, 10)
    t.clock.advance(9999)
    XCTAssertEqual(t.audio.restarts, 0, "ten seconds from the reopen, not eight")
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1)
  }

  func testAReopenOnAnOrdinaryLookingRouteNeverShortensAGrantedWindow() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.goLive()
    t.clock.advance(3000)
    t.audio.startupDeadline = MicStartupDeadline(sampleRate: 48000)
    t.audio.onMicReopened?("clock")
    XCTAssertEqual(t.last("call_mic")?["deadline_s"] as? Double, 10)
    t.clock.advance(9999)
    XCTAssertEqual(t.audio.restarts, 0)
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1)
  }

  func testAReopenGrowsAnOrdinaryWindowWhenTheNewRouteIsBluetooth() {
    let t = CallHarness()
    t.goLive()
    t.clock.advance(1000)
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.audio.onMicReopened?("route change")
    t.clock.advance(9999)
    XCTAssertEqual(t.audio.restarts, 0)
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1)
  }

  func testAReopenAfterTheFirstBufferOrAfterGivingUpChangesNothing() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.goLive()
    t.audio.mic(480, value: 0.3)
    t.socket.say(["type": "mic_ack", "token": 1])
    let logged = t.events.count
    t.audio.onMicReopened?("route change")
    t.clock.advance(30000)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertFalse(t.events[logged...].contains { $0.0 == "call_mic" && $0.1["reopened"] != nil })
  }

  func testAFlappingRouteRestartsTheWindowOnlyThreeTimes() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.goLive()
    for _ in 0..<CallSession.reopensPerWatch {
      t.clock.advance(5000)
      t.audio.onMicReopened?("route change")
    }
    t.clock.advance(5000)
    t.audio.onMicReopened?("route change")
    XCTAssertEqual(t.last("call_mic")?["action"] as? String, "reopen_kept")
    t.clock.advance(4999)
    XCTAssertEqual(t.audio.restarts, 0)
    t.clock.advance(1)
    XCTAssertEqual(t.audio.restarts, 1, "ten seconds from the third reopen")
  }

  func testHangupCancelsTheLongWatch() {
    let t = CallHarness()
    t.audio.startupDeadline = MicStartupDeadline(bluetooth: true)
    t.goLive()
    t.session.stop()
    t.clock.advance(30000)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertEqual(t.connects.count, 1)
  }

  func testAudioWatchdogWaitsOnlyUntilTheFirstBuffer() {
    func verdict(_ now: Double, lastBufferAt: Double = 0) -> CallWatchdog.Verdict {
      CallWatchdog.mic(
        now: now, armed: true, paused: false, armedAt: 1000, lastBufferAt: lastBufferAt,
        startupDeadlineMs: MicStartupDeadline(bluetooth: true).ms)
    }
    XCTAssertEqual(verdict(2500), .ok)
    XCTAssertEqual(verdict(10999), .ok)
    XCTAssertEqual(verdict(11000), .stalled)
    XCTAssertEqual(verdict(3499, lastBufferAt: 2000), .ok)
    XCTAssertEqual(verdict(3500, lastBufferAt: 2000), .stalled)
  }
}
