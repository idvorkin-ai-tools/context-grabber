//  What the call tells the bridge about itself beyond who is calling (story 1073, context-grabber-2k58; the Cockpit
//  keeps it for /debug/call): the device, the microphone and the outputs by the names iOS gives them, the audio
//  session, and the network. The start frame carries all of it; a route or network change mid-call sends its own
//  small frame. The app reads iOS into these; everything here is platform-free.

import Foundation

/// One end of the audio route: the name iOS shows for it and iOS's port type (`MicrophoneBuiltIn`, `Speaker`,
/// `BluetoothHFP`…). No UID: a Bluetooth port's carries the headset's hardware address.
public struct CallRoutePort: Equatable, Sendable {
  public var name: String
  public var type: String

  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }

  var fields: [String: Any] { ["name": name, "type": type] }
}

/// The microphone and the outputs the call is on.
public struct CallRoute: Equatable, Sendable {
  /// nil: no microphone.
  public var input: CallRoutePort?
  public var outputs: [CallRoutePort]

  public init(input: CallRoutePort?, outputs: [CallRoutePort]) {
    self.input = input
    self.outputs = outputs
  }

  var fields: [String: Any] { ["input": input?.fields ?? NSNull(), "outputs": outputs.map(\.fields)] }

  /// The log's line, as the devices line names it: `iPhone Microphone · Speaker`.
  public var description: String {
    let output = outputs.map(\.name).joined(separator: ", ")
    return "\(input?.name ?? "no microphone") · \(output.isEmpty ? "no output" : output)"
  }
}

/// The audio session under the call.
public struct CallAudioState: Equatable, Sendable {
  public var category: String
  public var mode: String
  public var sampleRate: Double
  public var ioBufferMs: Double
  /// Echo cancellation on the microphone; nil before the call's audio engine exists.
  public var voiceProcessing: Bool?

  public init(category: String, mode: String, sampleRate: Double, ioBufferMs: Double, voiceProcessing: Bool?) {
    self.category = category
    self.mode = mode
    self.sampleRate = sampleRate
    self.ioBufferMs = ioBufferMs
    self.voiceProcessing = voiceProcessing
  }

  var fields: [String: Any] {
    [
      "category": category, "mode": mode, "sample_rate": sampleRate, "io_buffer_ms": ioBufferMs.rounded(),
      "voice_processing": voiceProcessing ?? NSNull(),
    ]
  }
}

/// The phone or iPad: its model identifier (`iPhone17,2`) and system (`iOS 27.2`).
public struct CallDevice: Equatable, Sendable {
  public var model: String
  public var system: String

  public init(model: String, system: String) {
    self.model = model
    self.system = system
  }

  var fields: [String: Any] { ["model": model, "system": system] }
}

/// Everything the start frame's `meta` holds. The network is nil until the first reading.
public struct CallMeta: Equatable, Sendable {
  public var device: CallDevice
  public var route: CallRoute
  public var audio: CallAudioState
  public var network: CallNetworkPath?

  public init(device: CallDevice, route: CallRoute, audio: CallAudioState, network: CallNetworkPath?) {
    self.device = device
    self.route = route
    self.audio = audio
    self.network = network
  }

  var fields: [String: Any] {
    var f: [String: Any] = ["device": device.fields, "route": route.fields, "audio": audio.fields]
    if let network { f["network"] = network.fields }
    return f
  }
}
