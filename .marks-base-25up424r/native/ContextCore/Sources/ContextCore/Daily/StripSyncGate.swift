//  The strip sync's write-failure edges (#384, story 153). The publish gate says what a tap does with its month,
//  and the held steps are the counter steps made before iCloud's first sync, kept with their counter write as one.

import Foundation

/// Whether this device's months may go up. Closed until the first sync (`ready`), and closed again after any
/// recovery of this device's own iCloud months fails, or an arrival's write is refused, until a recovery succeeds:
/// publishing then could send a partial local month over iCloud's complete one (Codex on #378, #384).
public struct StripPublishGate: Equatable, Sendable {
  public private(set) var ready: Bool
  public private(set) var recovered = true

  public init(ready: Bool) { self.ready = ready }

  public var publishes: Bool { ready && recovered }

  /// What a tap on `day` does with its month.
  public enum Tap: Equatable, Sendable {
    /// Waiting for the first sync: the month goes up with every other once it comes.
    case hold(month: String)
    /// A recovery failed: try it again, and on success publish every month, this one included.
    case recoverFirst
    case publish(month: String)
  }

  public func tap(day: String) -> Tap {
    let month = StripSync.month(of: day)
    guard ready else { return .hold(month: month) }
    return recovered ? .publish(month: month) : .recoverFirst
  }

  /// The first sync came and its own recovery and replay landed.
  public mutating func opened() {
    ready = true
    recovered = true
  }

  public mutating func recovery(succeeded: Bool) { recovered = succeeded }

  /// A refused write while months arrived: this device's own rows may lag iCloud's.
  public mutating func arrivalFailed() { recovered = false }
}

/// A counter step made while waiting for the first sync: the row as it was before the first one, and their sum.
public struct StripHeldStep: Codable, Equatable, Sendable {
  public var item: String
  public var day: String
  /// The row before the first step, as value and updated_at; nil when there was none.
  public var original: [Int64]?
  public var net: Int

  public init(item: String, day: String, original: [Int64]?, net: Int) {
    self.item = item
    self.day = day
    self.original = original
    self.net = net
  }
}

/// The held steps, in `settings`, so a restart while waiting still lands them on the recovered count (#380). `strip`
/// and `settings` must share one connection: a step and its counter write are one transaction (#384).
public struct StripHeldSteps {
  public static let key = "strip_waiting_steps"
  private let strip: DailyStrip
  private let settings: SettingsStore

  public init(strip: DailyStrip, settings: SettingsStore) {
    self.strip = strip
    self.settings = settings
  }

  /// By `day/item`. A value that no longer decodes holds nothing.
  public func all() throws -> [String: StripHeldStep] {
    guard let json = try settings.get(Self.key) else { return [:] }
    return (try? JSONDecoder().decode([String: StripHeldStep].self, from: Data(json.utf8))) ?? [:]
  }

  public func clear() throws { try write([:]) }

  private func write(_ steps: [String: StripHeldStep]) throws {
    let json = String(decoding: try JSONEncoder().encode(steps), as: UTF8.self)
    try settings.set(Self.key, json)
  }

  /// This device's count of `item` on `day` steps by `step`, never below 0, and the new count comes back. While
  /// `holding` (no first sync yet) the step as applied is remembered too, in the same transaction: a refused write
  /// leaves both as they were, so a retried tap counts once.
  @discardableResult
  public func step(_ item: DailyItem, day: String, by step: Int, holding: Bool, at: Date = Date()) throws -> Int {
    try strip.inTransaction {
      let own = try strip.ownValue(item, day: day)
      let next = max(0, own + step)
      if holding {
        var steps = try all()
        let key = "\(day)/\(item.rawValue)"
        if steps[key] == nil {
          let original = try strip.ownRows(month: StripSync.month(of: day)).first { $0.day == day && $0.item == item }
          steps[key] = StripHeldStep(
            item: item.rawValue, day: day, original: original.map { [Int64($0.value), $0.updatedAt] }, net: 0)
        }
        steps[key]?.net += next - own
        try write(steps)
      }
      try strip.set(item, day: day, value: next, at: at)
      return next
    }
  }
}

/// What came of merging the keys that arrived from iCloud (#388): the months merged, by device, and the keys whose
/// write was refused, with why. A refused key costs only itself; a later full re-read picks it up.
public struct StripArrival: Equatable, Sendable {
  public var merged: [String: [String]] = [:]
  public var failed: [String: String] = [:]
}

extension DailyStrip {
  /// The strip keys among `keys` merged into this database, each on its own and all or nothing: this device's own
  /// months back into its table where newer, every other device's into its peer rows. A month older than `oldest`,
  /// a key `read` no longer finds (only its owner's pruning removes one) and any other key are passed over.
  public func absorb(keys: [String], device: String, oldest: String, read: (String) -> Data?) -> StripArrival {
    var arrival = StripArrival()
    for key in keys {
      guard let (from, month) = StripSync.parse(key: key), month >= oldest, let data = read(key) else { continue }
      do {
        try inTransaction {
          let rows = StripSync.decode(data)
          if from == device { try mergeOwn(rows) } else { try mergePeer(from, month: month, rows: rows) }
        }
        arrival.merged[from, default: []].append(month)
      } catch {
        arrival.failed[key] = "\(error)"
      }
    }
    arrival.merged = arrival.merged.mapValues { $0.sorted() }
    return arrival
  }
}

/// When a database waiting for iCloud's first sync stops waiting (#388 item 1, option A, Igor 2026-11-19). An
/// arrival may be only part of the download, so it opens nothing itself: a minute counted with nothing more arriving
/// does, each arrival starting the minute again. With no arrival at all, five minutes. Time counts only while online
/// and in the foreground, and a stretch that is broken starts over. All on the continuous clock the timer sleeps on,
/// never the wall clock, so setting the phone's clock back can't hold the wait shut (#972).
public struct StripFirstSyncWait: Equatable, Sendable {
  public typealias Instant = ContinuousClock.Instant

  public static let settle: Duration = .seconds(60)
  public static let quiet: Duration = .seconds(300)

  /// The arrival that started the wait settling, for the log.
  public private(set) var after: String?
  private var lastArrival: Instant?
  private var countingSince: Instant?

  public init() {}

  /// Whether time counts from `at`: online and in the foreground. Being told again while it counts moves nothing.
  public mutating func counting(_ on: Bool, at: Instant) {
    if !on {
      countingSince = nil
    } else if countingSince == nil {
      countingSince = at
    }
  }

  public mutating func arrived(_ why: String, at: Instant) {
    lastArrival = at
    if after == nil { after = why }
  }

  /// When the wait ends if nothing changes; nil while no time counts.
  public var deadline: Instant? {
    guard let since = countingSince else { return nil }
    guard let last = lastArrival else { return since.advanced(by: Self.quiet) }
    return max(since, last).advanced(by: Self.settle)
  }

  /// Whether the wait has ended by `now`, on the same clock.
  public func isDue(at now: Instant) -> Bool { deadline.map { $0 <= now } ?? false }

  public var why: String { lastArrival == nil ? "online_quiet" : "settled" }
}
