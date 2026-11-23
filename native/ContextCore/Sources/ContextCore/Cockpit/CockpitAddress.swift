//  Where the Cockpit is and the Origin a native POST sends it: the part of the Cockpit screen's page that the chat wire
//  and the board need, in ChatWireKit below ContextCore (plan 2026-11-22-contextcore-targets-plan.md). The rest of
//  `CockpitPage` extends it in ContextCore.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum CockpitPage {
  /// Igor's decision Cockpit, served only on the tailnet: reaching the host at all is the authentication.
  public static let url = "https://c-5004.squeaker-teeth.ts.net"
  public static let host = "c-5004.squeaker-teeth.ts.net"

  /// What a native POST sends as its `Origin`: the Cockpit's own, since the write boundary wants a browser's
  /// Origin and no token is set up (the Inbox and the archive both send it).
  public static func origin(of url: URL) -> String {
    let port = url.port.map { ":\($0)" } ?? ""
    return "\(url.scheme ?? "https")://\(url.host ?? "")\(port)"
  }
}
