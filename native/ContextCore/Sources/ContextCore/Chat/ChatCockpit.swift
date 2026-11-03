//  #525, stories 507–511 (chat spec, On a simulator): which Cockpit chat and the Inbox talk to. A simulator reaches the
//  tailnet too, so like the stats archive it talks to the real one only when pointed at it.

import Foundation

public enum ChatCockpit {
  /// A simulator's address when it was given none. `.invalid` never resolves (RFC 6761), so a route with no guard of
  /// its own, such as a board's turn, fails rather than finding the real Cockpit.
  public static let nowhere = "https://no-address.invalid"

  /// The reason, in the log and on the list.
  public static let noAddress = "This simulator has no Cockpit address, so chat stays here: set GRABBER_CHAT_URL"

  public static var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }

  /// `override`: GRABBER_CHAT_URL, where empty counts as unset.
  public static func address(override: String?, simulator: Bool = isSimulator) -> String {
    if let override, !override.isEmpty { return override }
    return simulator ? nowhere : CockpitPage.url
  }
}
