//  The network under a call, and the error a lost socket gave, as log fields (#440, #439, story 209): two calls
//  from home ended "connection lost" and the log could not say whether Wi-Fi gave way, the tailnet re-homed, or the
//  far end went. The app maps NWPath into CallNetworkPath; everything here is platform-free.

import Foundation

public struct CallNetworkPath: Equatable, Sendable {
  /// "satisfied", "unsatisfied" or "requiresConnection".
  public var status: String
  /// The types the path uses: "wifi", "cellular", "wired", "loopback", "other" (a tunnel such as the tailnet's
  /// shows as other).
  public var interfaces: [String]
  /// Every interface the path could use, in its order of preference (Wi-Fi and cellular both up reads both here).
  public var available: [String]
  /// Metered (cellular, a personal hotspot).
  public var expensive: Bool
  /// Low Data Mode.
  public var constrained: Bool

  public init(status: String, interfaces: [String], available: [String] = [], expensive: Bool, constrained: Bool) {
    self.status = status
    self.interfaces = interfaces
    self.available = available
    self.expensive = expensive
    self.constrained = constrained
  }

  public var fields: [String: Any] {
    [
      "status": status, "interfaces": interfaces.isEmpty ? "none" : interfaces.joined(separator: "+"),
      "available": available.isEmpty ? "none" : available.joined(separator: "+"),
      "expensive": expensive, "constrained": constrained,
    ]
  }
}

public enum SocketErrorDetail {
  /// The error's sentence, then its domain and code, the error underneath, and CFNetwork's stream error
  /// (domain 1 is POSIX: 57 not connected, 54 reset by peer, 60 timed out).
  public static func describe(_ error: Error) -> String {
    let e = error as NSError
    var parts = ["\(e.domain) \(e.code)"]
    if let u = e.userInfo[NSUnderlyingErrorKey] as? NSError { parts.append("under \(u.domain) \(u.code)") }
    if let domain = e.userInfo["_kCFStreamErrorDomainKey"] as? Int,
      let code = e.userInfo["_kCFStreamErrorCodeKey"] as? Int
    {
      parts.append("stream \(domain)/\(code)")
    }
    return "\(e.localizedDescription) (\(parts.joined(separator: "; ")))"
  }
}
