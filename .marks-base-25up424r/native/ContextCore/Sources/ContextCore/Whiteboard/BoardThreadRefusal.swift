//  A board's Larry thread that iCloud's production side refused (bead context-grabber-irm0, after #1161). The
//  thread is a field production lacks until the development schema is deployed there, and a TestFlight build's save
//  of a board carrying it is turned down whole, ink and all. The sync sends that board once more without its thread,
//  so ink always goes up, and offers no threads for the rest of the launch, so the board isn't sent twice every sync.
//  CloudKit's errors arrive as the `NSError`s they bridge to, so this stays platform-free and host-tested.

import Foundation

/// Whether this launch still sends boards' threads up with their records.
public struct BoardThreadRefusal: Sendable {
  /// iCloud refused a board for its thread earlier this launch.
  public private(set) var refused = false

  public init() {}

  /// The threads to offer this sync (board id to thread): none once iCloud refused one this launch, so a board waiting
  /// only on its thread isn't sent up again; the next launch offers them again.
  public func offered(_ threads: [String: String]) -> [String: String] { refused ? [:] : threads }

  /// The board went up without its thread; the rest of this launch's uploads leave theirs off.
  public mutating func dropped() { refused = true }

  /// Whether a board's refused save is worth sending once more without its thread: it carried one, and CloudKit
  /// turned it down as invalid arguments (code 12, what production says to a field its schema lacks) or said
  /// "production schema", on the error itself or one record's error in a partial failure (code 2). Keyed on the code,
  /// not the server's wording, which is unobserved: a wrong guess costs one extra upload, a missed one the whole sync.
  public static func retryWithoutThread(_ error: Error, sentThread: Bool) -> Bool {
    guard sentThread else { return false }
    let e = error as NSError
    guard e.domain == CloudErrorFields.cloudKitDomain else { return false }
    if refusesField(e) { return true }
    guard e.code == partialFailure, let byID = e.userInfo[CloudErrorFields.partialKey] as? [AnyHashable: Any] else {
      return false
    }
    return byID.values.contains { ($0 as? Error).map { refusesField($0 as NSError) } ?? false }
  }

  static let invalidArguments = 12
  static let partialFailure = 2

  private static func refusesField(_ e: NSError) -> Bool {
    guard e.domain == CloudErrorFields.cloudKitDomain else { return false }
    if e.code == invalidArguments { return true }
    let server = (e.userInfo[CloudErrorFields.serverKey] as? String) ?? ""
    return server.localizedCaseInsensitiveContains("production schema")
  }
}
