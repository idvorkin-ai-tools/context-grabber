//  The Call screen's devices menu (story 086, #293): which microphones and outputs it offers, by the names iOS
//  gives them, and which one is checked. The roster is the audio bridge's (AudioRouting), so the Cockpit page and
//  the Call screen name a device the same way.

import Foundation

public enum CallDevices {
  public struct Item: Equatable, Sendable {
    /// nil is Automatic: hand the choice back to iOS.
    public let id: String?
    public let name: String
    public let checked: Bool
  }

  /// Automatic first, named after the microphone iOS picked, then every microphone. `chosen` is what was picked
  /// this call, nil for none (or Automatic): then Automatic is checked, otherwise the live microphone is.
  public static func microphones(_ route: AudioRouteSnapshot, chosen: String?) -> [Item] {
    let live = route.currentInput
    let automatic = live.map { "Automatic \u{00B7} \($0.name)" } ?? "Automatic"
    return [Item(id: nil, name: automatic, checked: chosen == nil)]
      + route.inputs.map { Item(id: $0.id, name: $0.name, checked: chosen != nil && $0.id == live?.id) }
  }

  /// The audio bridge's outputs (Automatic, Speaker, any headset), the live one checked; Automatic when nothing
  /// was picked this call.
  public static func outputs(_ route: AudioRouteSnapshot, chosen: String?) -> [Item] {
    route.outputs.map { o in
      let checked = chosen == nil ? o.id == AudioRouting.auto : o.id == route.currentOutput?.id
      return Item(id: o.id, name: o.name, checked: checked)
    }
  }
}
