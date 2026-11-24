//  Story 1073, context-grabber-2k58: what the call tells the bridge about itself, read from iOS — the device, the
//  route by the names iOS gives its ports, the audio session. Nothing here asks for a permission or waits.

import AVFoundation
import ContextCore
import UIKit

extension CallRoute {
  /// The route iOS has the call on now. Ports carry their name and type, never their UID (a Bluetooth port's is
  /// the headset's hardware address).
  static func current() -> CallRoute {
    let route = AVAudioSession.sharedInstance().currentRoute
    let port = { (p: AVAudioSessionPortDescription) in CallRoutePort(name: p.portName, type: p.portType.rawValue) }
    return CallRoute(input: route.inputs.first.map(port), outputs: route.outputs.map(port))
  }
}

extension CallAudioState {
  static func current(voiceProcessing: Bool?) -> CallAudioState {
    let session = AVAudioSession.sharedInstance()
    return CallAudioState(
      category: session.category.rawValue, mode: session.mode.rawValue, sampleRate: session.sampleRate,
      ioBufferMs: session.ioBufferDuration * 1000, voiceProcessing: voiceProcessing)
  }
}

extension CallDevice {
  /// `iPhone17,2` on a device; the simulated model's identifier in the simulator (where the hardware reads `arm64`).
  @MainActor static func current() -> CallDevice {
    var info = utsname()
    uname(&info)
    let machine = withUnsafeBytes(of: &info.machine) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
    let device = UIDevice.current
    return CallDevice(model: model, system: "\(device.systemName) \(device.systemVersion)")
  }
}
