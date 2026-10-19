//  #404, story 226: the daily strip and Health numbers for the usage tile, each dated independently so a strip
//  edit cannot make yesterday's Health current. The tile draws each only on the local day it was taken.

import Foundation

public struct TodayGlance: Codable, Equatable, Sendable {
  public struct Item: Codable, Equatable, Sendable {
    /// The metric, so the tile can put its symbol before it.
    public let key: String
    /// A check mark, counter, short Health number, or "—".
    public let value: String
  }

  /// The local day it was taken, as the strip keys days.
  public let day: String
  public let items: [Item]

  /// #404: sleep gives way to the daily strip; keep the other Today card numbers.
  public static let keys: [MetricKey] = [.movement, .hrv, .exerciseMinutes]

  public init(day: String, items: [Item]) {
    self.day = day
    self.items = items
  }

  public init(cards: [MetricCard], day: String) {
    self.day = day
    items = Self.keys.map { key in
      let value = cards.first { $0.key == key }?.value ?? MirrorText.none
      return Item(key: key.rawValue, value: Self.short(value, key: key))
    }
  }

  /// The app's displayed values, including meditation from breathing or Health and counts merged across peers.
  public init(day: String, values: [DailyItem: Int], meditationDone: Bool) {
    self.day = day
    items = [DailyItem.meditation, .journal, .balloons, .magic].map { item in
      let count = max(0, values[item] ?? 0)
      let done = item == .meditation ? meditationDone : count > 0
      return Item(key: item.rawValue, value: item.isCounter ? String(count) : (done ? "✓" : "○"))
    }
  }

  /// #404: drop sleep even from a reading written by the previous app version.
  public var healthItems: [Item] { items.filter { item in Self.keys.contains { $0.rawValue == item.key } } }

  /// Only today's numbers are drawn: after midnight the line goes until the app looks again.
  public func isToday(_ today: String) -> Bool { day == today }

  /// The card's words, cut to fit a widget's line: "65.2 ms" is 65 ms, "38 min" 38m.
  static func short(_ value: String, key: MetricKey) -> String {
    guard value != MirrorText.none else { return value }
    switch key {
    case .hrv:
      let number = value.replacingOccurrences(of: " ms", with: "")
      return Double(number).map { "\(Int($0.rounded())) ms" } ?? value
    case .exerciseMinutes: return value.replacingOccurrences(of: " min", with: "m")
    default: return value
    }
  }

  public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

  public static func decode(_ data: Data?) -> TodayGlance? {
    data.flatMap { try? JSONDecoder().decode(TodayGlance.self, from: $0) }
  }
}
