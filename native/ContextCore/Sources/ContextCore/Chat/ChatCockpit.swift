//  #525, stories 507–511 (chat spec, On a simulator): which Cockpit chat and the Inbox talk to. A simulator reaches the
//  tailnet too, so like the stats archive it talks to the real one only when pointed at it. #638, stories 582-583: a
//  Mac build is not a simulator and reaches the tailnet too, so the same rule holds for it, on every route.

import Foundation

public enum ChatCockpit {
  /// A simulator's or a Mac build's address when it was given none. `.invalid` never resolves (RFC 6761), so a route with no guard of
  /// its own, such as a board's turn, fails rather than finding the real Cockpit.
  public static let nowhere = "https://no-address.invalid"

  /// The reason, in the log and on the list.
  public static var noAddress: String { noAddress(mac: isMac) }

  public static func noAddress(mac: Bool) -> String {
    "This \(mac ? "Mac build" : "simulator") has no Cockpit address, so chat stays here: set GRABBER_CHAT_URL"
  }

  public static var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }

  public static var isMac: Bool {
    #if targetEnvironment(macCatalyst)
      return true
    #else
      return false
    #endif
  }

  /// `override`: GRABBER_CHAT_URL, where empty counts as unset. `simulator`: pointed only, as a Mac build is too.
  public static func address(override: String?, simulator: Bool = isSimulator || isMac) -> String {
    if let override, !override.isEmpty { return override }
    return simulator ? nowhere : CockpitPage.url
  }

  /// The routes a simulator keeps on the real Cockpit, the page and the usage strip: only a Mac build needs pointing.
  public static func pageAddress(override: String?, mac: Bool = isMac) -> String {
    address(override: override, simulator: mac)
  }

  /// A call's bridge and voices. A phone and a simulator take no override here, GRABBER_CALL is what points their
  /// bridge (and starts a call); a Mac build follows GRABBER_CHAT_URL.
  public static func callAddress(chatOverride: String?, mac: Bool = isMac) -> String {
    mac ? address(override: chatOverride, simulator: true) : CockpitPage.url
  }
}
