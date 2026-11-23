//  Story 1136 (#1245–#1253, #1259, #1268): a chat read that fails because the Cockpit can't be reached for a moment
//  (its proxy answering 502, 503 or 504, a timeout, a refused or dropped connection) shows its error but files no
//  automatic report until such failures have gone on, with no read getting through, for two minutes; then one report
//  for that outage. A read failing because the device's own connection is down never files.

import Foundation

/// One outage of the Cockpit, as the chat's reads see it: when it started, how many reads failed, whether it filed.
public struct CockpitOutage: Equatable, Sendable {
  /// How long failures must go on, with no read getting through, before the outage files its one report.
  public static let fileAfterMs: Int64 = 120_000
  /// A pause with no read this long (the thread closed, the app in the background) starts the count again.
  public static let gapMs: Int64 = 60_000

  /// What a failed read was.
  public enum Kind: Equatable, Sendable {
    /// The Cockpit can't be reached for now: a 502, 503 or 504, a timeout, a refused or dropped connection, an unfound
    /// host.
    case away
    /// The device's own connection is down, whether or not the app has noticed yet.
    case deviceOffline
    /// Anything else (a 404, an answer the app can't read): a bug worth a report at once.
    case other
  }

  /// What the failed read's error on screen does about an automatic report.
  public enum Verdict: Equatable, Sendable {
    /// Files as any error does (story 155).
    case file
    /// Files nothing: the outage is young, or already filed, or the device is offline.
    case quiet
    /// Files nothing itself; the outage has lasted `ms` over `failures` reads and files its one report now.
    case fileOutage(ms: Int64, failures: Int)
  }

  /// An outage that ended: how long it lasted, how many reads failed, whether it filed.
  public struct Ended: Equatable, Sendable {
    public let ms: Int64
    public let failures: Int
    public let filed: Bool
  }

  public private(set) var started: Int64?
  public private(set) var last: Int64?
  public private(set) var failures = 0
  public private(set) var filed = false

  public init() {}

  static let awayStatuses: Set<Int> = [502, 503, 504]
  static let awayCodes: Set<URLError.Code> = [
    .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost,
  ]
  static let offlineCodes: Set<URLError.Code> = [
    .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff,
  ]

  /// A read the Cockpit answered with this status (not 200, or a 200 the app could not read).
  public static func kind(status: Int) -> Kind { awayStatuses.contains(status) ? .away : .other }

  /// A read that threw.
  public static func kind(_ error: Error) -> Kind {
    guard let code = (error as? URLError)?.code else { return .other }
    if offlineCodes.contains(code) { return .deviceOffline }
    return awayCodes.contains(code) ? .away : .other
  }

  /// A read failed at `now` (ms): whether its error files.
  public mutating func failed(_ kind: Kind, now: Int64) -> Verdict {
    switch kind {
    case .other: return .file
    case .deviceOffline: return .quiet
    case .away:
      if let last, now - last > Self.gapMs { self = Self() }
      let start = started ?? now
      started = start
      last = now
      failures += 1
      guard !filed, now - start >= Self.fileAfterMs else { return .quiet }
      filed = true
      return .fileOutage(ms: now - start, failures: failures)
    }
  }

  /// A read got through: the outage, if there was one, is over.
  public mutating func succeeded(now: Int64) -> Ended? {
    defer { self = Self() }
    guard let started else { return nil }
    return Ended(ms: now - started, failures: failures, filed: filed)
  }
}
