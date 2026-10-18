//  The daily strip across devices (#376, story 153; plan 2026-10-17-strip-sync-plan.md). Each device writes only its
//  own iCloud keys, one per month, `strip.<device>.<yyyy-mm>`, since a key is last-writer-wins; the others are read
//  into `daily_strip_peers` and merged: counts add up, a check is its latest change.

import Foundation

public struct StripRow: Equatable, Sendable {
  public var day: String
  public var item: DailyItem
  public var value: Int
  /// Unix ms; 0 for a row from before sync.
  public var updatedAt: Int64

  public init(day: String, item: DailyItem, value: Int, updatedAt: Int64) {
    self.day = day
    self.item = item
    self.value = value
    self.updatedAt = updatedAt
  }

  init?(row: [String: SQLiteValue]) {
    guard let day = row["date_key"]?.textValue, let item = row["item"]?.textValue.flatMap(DailyItem.init(rawValue:)),
      let value = row["value"]?.intValue
    else { return nil }
    self.init(day: day, item: item, value: Int(value), updatedAt: row["updated_at"]?.intValue ?? 0)
  }

  /// One item's rows from every device, by day: a counter sums, a check takes the latest change (ties: the higher).
  static func merge(_ rows: [StripRow], item: DailyItem) -> [String: Int] {
    var out: [String: Int] = [:]
    var latest: [String: StripRow] = [:]
    for r in rows where r.item == item {
      if item.isCounter {
        out[r.day, default: 0] += r.value
      } else if let seen = latest[r.day],
        (seen.updatedAt, seen.value) >= (r.updatedAt, r.value)
      {
        continue
      } else {
        latest[r.day] = r
      }
    }
    if !item.isCounter { out = latest.mapValues(\.value) }
    return out
  }
}

public enum StripSync {
  static let prefix = "strip."

  public static func key(device: String, month: String) -> String { "\(prefix)\(device).\(month)" }

  /// The device and month a key names; nil for any other key.
  public static func parse(key: String) -> (device: String, month: String)? {
    guard key.hasPrefix(prefix) else { return nil }
    let rest = key.dropFirst(prefix.count)
    guard let dot = rest.lastIndex(of: "."), dot != rest.startIndex else { return nil }
    let month = String(rest[rest.index(after: dot)...])
    guard month.count == 7, month.dropFirst(4).first == "-" else { return nil }
    return (String(rest[..<dot]), month)
  }

  /// `yyyy-mm` of a `yyyy-mm-dd` day.
  public static func month(of day: String) -> String { String(day.prefix(7)) }

  /// One device's rows as their monthly values: `{"<day>": {"<item>": [value, updated_at]}}`.
  public static func encode(_ rows: [StripRow]) -> [String: Data] {
    var months: [String: [String: [String: [Int64]]]] = [:]
    for r in rows {
      months[month(of: r.day), default: [:]][r.day, default: [:]][r.item.rawValue] = [Int64(r.value), r.updatedAt]
    }
    return months.compactMapValues { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }
  }

  /// A monthly value back into rows; unknown items and malformed entries are skipped.
  public static func decode(_ data: Data) -> [StripRow] {
    guard let days = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: [NSNumber]]] else {
      return []
    }
    return days.flatMap { day, items in
      items.compactMap { name, pair -> StripRow? in
        guard let item = DailyItem(rawValue: name), pair.count == 2 else { return nil }
        return StripRow(day: day, item: item, value: max(0, pair[0].intValue), updatedAt: pair[1].int64Value)
      }
    }
  }
}
