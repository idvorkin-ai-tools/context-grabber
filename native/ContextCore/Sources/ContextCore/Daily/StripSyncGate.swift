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
