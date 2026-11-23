//  Stories 1604–1606 (bead context-grabber-3kgu; #1352, #1353, #1361): the chat list and an open thread say plainly
//  when the Cockpit is down (any 5xx, a timeout, a refused or dropped connection, an unfound host), with what they last
//  read still under the banner. One screen's spell: the banner shows at the first failed read when nothing is loaded,
//  else at the second in a row, and goes at the first read that gets through. Spec: 2026-10-25-native-chat-design.md,
//  *Saying plainly when the Cockpit is down*.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct CockpitDown: Equatable, Sendable {
  /// The whiteboard's words for the same thing (WhiteboardLarryClock), so the two read alike.
  public static let title = "Cockpit not answering"
  /// A loaded screen shows the banner at this many failed reads in a row: one blip the next poll heals shows nothing.
  public static let showAtFailures = 2

  /// When this screen last read (ms), nil when it has not since launch.
  public private(set) var lastGood: Int64?
  /// When this spell of failures started (ms), nil while reads get through.
  public private(set) var since: Int64?
  /// How the spell's first failure went (`answered HTTP 502`, `failed (…)`): kept so the words stay the same.
  public private(set) var how: String?
  public private(set) var failures = 0
  public private(set) var showing = false

  public init() {}

  /// A read the Cockpit answered with this status: any 5xx is down, a 4xx is a plain error.
  public static func isDown(status: Int) -> Bool { CockpitOutage.kind(status: status) == .away }

  /// A read that threw: a timeout, a refused, dropped or unfound connection. The device offline is not this.
  public static func isDown(_ error: Error) -> Bool { CockpitOutage.kind(error) == .away }

  public static func how(status: Int) -> String { "answered HTTP \(status)" }
  public static func how(_ error: Error) -> String { "failed (\(error.localizedDescription))" }

  /// A down read at `now`; `loaded` is whether the screen holds what an earlier read gave it. True when the banner shows.
  public mutating func failed(_ how: String, loaded: Bool, now: Int64) -> Bool {
    if since == nil {
      since = now
      self.how = how
    }
    failures += 1
    if !loaded || failures >= Self.showAtFailures { showing = true }
    return showing
  }

  /// A read got through: the spell, and the banner, are over.
  public mutating func answered(now: Int64) {
    self = Self()
    lastGood = now
  }

  /// The banner's copyable words: what failed and how, since when, the last good read. Nothing in them changes while
  /// the spell lasts, so a poll failing the same way again changes nothing on screen or in the log.
  public func problem(what: String, timeZone: TimeZone) -> String {
    let start = since ?? lastGood ?? 0
    let good =
      lastGood.map { "last good read \(Self.clock($0, day: start, timeZone))" } ?? "no good read since the app opened"
    return "\(Self.title) — \(what) \(how ?? "failed") since \(Self.clock(start, day: start, timeZone)); \(good). "
      + "Your messages are kept and go when it answers."
  }

  /// `HH:mm`, with the date first when `ms` falls on another local day than `day`.
  static func clock(_ ms: Int64, day: Int64, _ timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let date = Date(timeIntervalSince1970: Double(ms) / 1000)
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = timeZone
    let sameDay = calendar.isDate(date, inSameDayAs: Date(timeIntervalSince1970: Double(day) / 1000))
    format.dateFormat = sameDay ? "HH:mm" : "yyyy-MM-dd HH:mm"
    return format.string(from: date)
  }
}
