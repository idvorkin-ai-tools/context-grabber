//  Story 086 / #293: the Call screen's devices menu, from the same roster the Cockpit page gets.

import ContextCore
import XCTest

final class CallDevicesTests: XCTestCase {
  private let phone = AudioDevice(id: "Built-In Microphone", name: "iPhone Microphone", type: "MicrophoneBuiltIn")
  private let usb = AudioDevice(id: "AppleUSBAudioEngine:1", name: "USBAudio1.0", type: "USBAudio")
  private let airpods = AudioDevice(id: "AA:BB-tacl", name: "AirPods Pro", type: "BluetoothHFP")

  private func route(live: AudioDevice?, output: AudioDevice?) -> AudioRouteSnapshot {
    let inputs = [phone, usb, airpods]
    return AudioRouteSnapshot(
      inputs: inputs, outputs: AudioRouting.outputs(availableInputs: inputs, routeOutputs: []), currentInput: live,
      currentOutput: output)
  }

  func testAutomaticIsNamedAfterWhatIOSPickedAndCheckedUntilAPick() {
    let items = CallDevices.microphones(route(live: usb, output: nil), chosen: nil)
    XCTAssertEqual(
      items.map(\.name), ["Automatic \u{00B7} USBAudio1.0", "iPhone Microphone", "USBAudio1.0", "AirPods Pro"])
    XCTAssertEqual(items.filter(\.checked).map(\.name), ["Automatic \u{00B7} USBAudio1.0"])
    XCTAssertNil(items[0].id)
  }

  func testAPickedMicrophoneIsTheCheckedOne() {
    let items = CallDevices.microphones(route(live: airpods, output: nil), chosen: airpods.id)
    XCTAssertEqual(items.filter(\.checked).map(\.id), [airpods.id])
  }

  func testNoMicrophoneYetStillOffersAutomatic() {
    let items = CallDevices.microphones(route(live: nil, output: nil), chosen: nil)
    XCTAssertEqual(items.first?.name, "Automatic")
    XCTAssertTrue(items.first?.checked ?? false)
  }

  func testOutputsAreTheBridgesWithTheLiveOneCheckedAfterAPick() {
    let speaker = AudioDevice(id: AudioRouting.speaker, name: "Speaker", type: "Speaker")
    let untouched = CallDevices.outputs(route(live: phone, output: speaker), chosen: nil)
    XCTAssertEqual(Array(untouched.map(\.name).prefix(2)), ["Automatic", "Speaker"])
    XCTAssertTrue(untouched.map(\.name).contains("AirPods Pro"))
    XCTAssertEqual(untouched.filter(\.checked).map(\.name), ["Automatic"])
    let picked = CallDevices.outputs(route(live: phone, output: speaker), chosen: AudioRouting.speaker)
    XCTAssertEqual(picked.filter(\.checked).map(\.name), ["Speaker"])
  }
}
