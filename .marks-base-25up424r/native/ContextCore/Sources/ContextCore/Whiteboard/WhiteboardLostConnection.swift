//  #1136 (stories 908, 909): the system dropping the connection under Larry's turn is not an outage. On the iPad it came, in
//  every log that had one, as the app left the screen for a moment while the picture was going, and landed just before
//  the app was back. One more try, once the app is back, is what Igor would have done himself; a second loss, or any
//  other error, is said as before.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum WhiteboardLostConnection {
  /// What became of the one more try, for the turn's log line.
  public struct Record: Equatable {
    /// Which request lost its connection: `upload` (the picture) or `message` (the message naming it).
    public var step: String
    /// The URLError code, -1005.
    public var code: Int
    /// The second try was made (false: the turn had been taken over, or the app never came back in time).
    public var tried = false
    /// The second try was answered; nil until it is made.
    public var worked: Bool?

    public init(step: String, code: Int) {
      self.step = step
      self.code = code
    }

    public var logFields: [String: Any] {
      var out: [String: Any] = ["lost_step": step, "lost_code": code, "lost_retried": tried]
      if let worked { out["lost_retry_ok"] = worked }
      return out
    }
  }

  /// The connection was lost under the request, never the network missing (-1009) or the Cockpit not answering.
  public static func isLost(_ error: Error) -> Bool {
    (error as? URLError)?.code == .networkConnectionLost
  }

  /// `send`, and on a lost connection, once per hand-off (`record` is nil until one is used), `send` again if `again`
  /// says so after waiting for the app. Anything else, a second loss, or `again` saying no throws as it came.
  public static func run<T>(
    _ step: String, record: inout Record?, isolation: isolated (any Actor)? = #isolation,
    again: (Record) async -> Bool, send: () async throws -> T
  ) async throws -> T {
    do {
      return try await send()
    } catch let error where isLost(error) && record == nil {
      var used = Record(step: step, code: (error as? URLError)?.code.rawValue ?? 0)
      record = used
      guard await again(used) else { throw error }
      used.tried = true
      do {
        let value = try await send()
        used.worked = true
        record = used
        return value
      } catch {
        used.worked = false
        record = used
        throw error
      }
    }
  }
}
