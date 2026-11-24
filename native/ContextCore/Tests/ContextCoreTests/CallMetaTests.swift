//  Story 1073, context-grabber-2k58: what the call tells the bridge about itself, the Cockpit's /debug/call. The start
//  frame carries the device, the route, the audio and the network; a mid-call change of route or network sends one
//  small frame; a route change that leaves the same devices sends none.

import ContextCore
import XCTest

final class CallMetaTests: XCTestCase {
  static let phoneRoute = CallRoute(
    input: CallRoutePort(name: "iPhone Microphone", type: "MicrophoneBuiltIn"),
    outputs: [CallRoutePort(name: "Speaker", type: "Speaker")])
  static let airPods = CallRoute(
    input: CallRoutePort(name: "AirPods Pro", type: "BluetoothHFP"),
    outputs: [CallRoutePort(name: "AirPods Pro", type: "BluetoothHFP")])
  static let audio = CallAudioState(
    category: "AVAudioSessionCategoryPlayAndRecord", mode: "AVAudioSessionModeVoiceChat", sampleRate: 24000,
    ioBufferMs: 10.4, voiceProcessing: true)
  static let wifi = CallNetworkPath(
    status: "satisfied", interfaces: ["wifi"], available: ["wifi", "cellular"], expensive: false, constrained: false)
  static let meta = CallMeta(
    device: CallDevice(model: "iPhone17,2", system: "iOS 27.2"), route: phoneRoute, audio: audio, network: wifi)

  private func object(_ s: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any]) ?? [:]
  }

  func testTheStartFrameCarriesTheMeta() {
    let start = object(CallProtocol.startFrame(backend: .direct, build: "abc", meta: Self.meta))
    let meta = start["meta"] as? [String: Any]
    XCTAssertEqual((meta?["device"] as? [String: Any])?["model"] as? String, "iPhone17,2")
    XCTAssertEqual((meta?["device"] as? [String: Any])?["system"] as? String, "iOS 27.2")
    let route = meta?["route"] as? [String: Any]
    XCTAssertEqual((route?["input"] as? [String: Any])?["name"] as? String, "iPhone Microphone")
    XCTAssertEqual((route?["input"] as? [String: Any])?["type"] as? String, "MicrophoneBuiltIn")
    XCTAssertEqual((route?["outputs"] as? [[String: Any]])?.map { $0["name"] as? String }, ["Speaker"])
    let audio = meta?["audio"] as? [String: Any]
    XCTAssertEqual(audio?["mode"] as? String, "AVAudioSessionModeVoiceChat")
    XCTAssertEqual(audio?["sample_rate"] as? Double, 24000)
    XCTAssertEqual(audio?["io_buffer_ms"] as? Double, 10, "rounded")
    XCTAssertEqual(audio?["voice_processing"] as? Bool, true)
    let network = meta?["network"] as? [String: Any]
    XCTAssertEqual(network?["interfaces"] as? String, "wifi")
    XCTAssertEqual(network?["available"] as? String, "wifi+cellular")
    XCTAssertEqual(start["build"] as? String, "abc", "the existing keys stay where they are")
  }

  func testWhatThePhoneDoesNotKnowIsLeftOutOrNull() {
    var meta = Self.meta
    meta.network = nil
    meta.route = CallRoute(input: nil, outputs: [])
    meta.audio.voiceProcessing = nil
    let start = object(CallProtocol.startFrame(backend: .eleven, meta: meta))
    let m = start["meta"] as? [String: Any]
    XCTAssertNil(m?["network"], "no reading yet: no key")
    XCTAssertTrue((m?["route"] as? [String: Any])?["input"] is NSNull, "no microphone is null")
    XCTAssertTrue((m?["audio"] as? [String: Any])?["voice_processing"] is NSNull)
    XCTAssertNil(object(CallProtocol.startFrame(backend: .eleven))["meta"], "no meta: no key")
  }

  func testNoHardwareIdentifierRidesTheWire() {
    let text = CallProtocol.startFrame(backend: .eleven, meta: Self.meta)
    XCTAssertFalse(text.contains("uid"))
    XCTAssertFalse(text.contains("\"id\""))
  }

  func testRouteAndNetworkFrames() {
    let route = object(
      CallProtocol.routeFrame(
        Self.airPods, audio: Self.audio, reason: "newDeviceAvailable", at: "2026-11-24T14:20:05.123Z"))
    XCTAssertEqual(route["type"] as? String, "route")
    XCTAssertEqual(route["reason"] as? String, "newDeviceAvailable")
    XCTAssertEqual(route["at"] as? String, "2026-11-24T14:20:05.123Z")
    XCTAssertEqual((route["input"] as? [String: Any])?["name"] as? String, "AirPods Pro")
    XCTAssertEqual((route["outputs"] as? [[String: Any]])?.first?["type"] as? String, "BluetoothHFP")
    XCTAssertEqual((route["audio"] as? [String: Any])?["voice_processing"] as? Bool, true)
    let network = object(CallProtocol.networkFrame(Self.wifi, at: "2026-11-24T14:21:00.000Z"))
    XCTAssertEqual(network["type"] as? String, "network")
    XCTAssertEqual(network["status"] as? String, "satisfied")
    XCTAssertEqual(network["interfaces"] as? String, "wifi")
    XCTAssertEqual(network["at"] as? String, "2026-11-24T14:21:00.000Z")
  }
}

final class CallSessionMetaTests: XCTestCase {
  private func harness() -> CallHarness {
    let t = CallHarness()
    t.meta = CallMetaTests.meta
    return t
  }

  func testTheStartFrameTakesTheMetaAtTheMomentTheSocketOpens() {
    let t = harness()
    t.session.start(.eleven)
    t.meta?.route = CallMetaTests.airPods  // the route the call is on when the bridge answers
    t.socket.open()
    let meta = t.socket.frames.first?["meta"] as? [String: Any]
    let input = (meta?["route"] as? [String: Any])?["input"] as? [String: Any]
    XCTAssertEqual(input?["name"] as? String, "AirPods Pro")
  }

  func testAChangedRouteSendsOneFrameAndTheSameRouteSendsNone() {
    let t = harness()
    t.goLive()
    t.session.routeChanged(CallMetaTests.phoneRoute, audio: CallMetaTests.audio, reason: "categoryChange")
    XCTAssertFalse(t.socket.types.contains("route"), "the start already named this route")
    t.session.routeChanged(CallMetaTests.airPods, audio: CallMetaTests.audio, reason: "newDeviceAvailable")
    t.session.routeChanged(CallMetaTests.airPods, audio: CallMetaTests.audio, reason: "override")
    XCTAssertEqual(t.socket.types.filter { $0 == "route" }.count, 1)
    let route = t.socket.frames.last { $0["type"] as? String == "route" }
    XCTAssertEqual(route?["reason"] as? String, "newDeviceAvailable")
    XCTAssertNotNil(route?["at"] as? String)
    XCTAssertEqual(t.last("call_sent")?["frame"] as? String, "route")
    t.session.routeChanged(CallMetaTests.phoneRoute, audio: CallMetaTests.audio, reason: "oldDeviceUnavailable")
    XCTAssertEqual(t.socket.types.filter { $0 == "route" }.count, 2, "taking them out is a change too")
  }

  func testNothingIsSentBeforeTheSocketOpensOrAfterTheCallEnds() {
    let t = harness()
    t.session.routeChanged(CallMetaTests.airPods, audio: CallMetaTests.audio, reason: "newDeviceAvailable")
    t.session.networkPathChanged(CallMetaTests.wifi)
    t.session.start(.eleven)
    t.session.routeChanged(CallMetaTests.airPods, audio: CallMetaTests.audio, reason: "newDeviceAvailable")
    XCTAssertTrue(t.socket.texts.isEmpty, "connecting, socket not open")
    t.socket.open()
    t.socket.say(["type": "ready", "out_rate": 24000, "backend": "eleven", "session": "s1"])
    t.session.stop()
    let sent = t.socket.texts.count
    t.session.routeChanged(CallMetaTests.phoneRoute, audio: CallMetaTests.audio, reason: "oldDeviceUnavailable")
    t.session.networkPathChanged(CallMetaTests.wifi)
    XCTAssertEqual(t.socket.texts.count, sent)
  }

  func testANetworkChangeMidCallSendsAFrame() {
    let t = harness()
    t.goLive()
    let cellular = CallNetworkPath(
      status: "satisfied", interfaces: ["cellular"], available: ["cellular"], expensive: true, constrained: false)
    t.session.networkPathChanged(cellular)
    let frame = t.socket.frames.last
    XCTAssertEqual(frame?["type"] as? String, "network")
    XCTAssertEqual(frame?["interfaces"] as? String, "cellular")
    XCTAssertEqual(frame?["expensive"] as? Bool, true)
  }

  func testNoMetaProviderSendsTheStartFrameAsBefore() {
    let t = CallHarness()
    t.goLive()
    XCTAssertNil(t.socket.frames.first?["meta"])
  }
}
