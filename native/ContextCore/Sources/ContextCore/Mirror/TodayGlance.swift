//  #396, story 226 (live tile spec, "Today's numbers"): the Today card's four numbers, short, for the usage tile. The
//  app writes one each time it looks at Health; the tile draws it only on the day it was taken.

import Foundation

public struct TodayGlance: Codable, Equatable, Sendable {
  public struct Item: Codable, Equatable, Sendable {
    /// The metric, so the tile can put its symbol before it.
    public let key: String
    /// "5.7h", "7,399", "65 ms", "38m", or "—".
    public let value: String
  }

  /// The local day it was taken, as the strip keys days.
  public let day: String
  public let items: [Item]

  /// The four the Today card shows, in its order.
  public static let keys: [MetricKey] = [.sleep, .movement, .hrv, .exerciseMinutes]

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

  /// Only today's numbers are drawn: after midnight the line goes until the app looks again.
  public func isToday(_ today: String) -> Bool { day == today }

  /// The card's words, cut to fit a widget's line: "5.7h asleep" is 5.7h, "65.2 ms" 65 ms, "38 min" 38m.
  static func short(_ value: String, key: MetricKey) -> String {
    guard value != MirrorText.none else { return value }
    switch key {
    case .sleep: return value.replacingOccurrences(of: " asleep", with: "")
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
