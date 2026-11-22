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

  /// How many months, this one included, iCloud carries (Codex on #378: the store's quota is 1 MB, and ten years
  /// on two devices is about that). Older months stay in each device's own database; a new device starts with a year.
  public static let monthsKept = 12

  /// The oldest month iCloud carries on `today` (`yyyy-mm-dd`): eleven months before today's.
  public static func oldestKept(today: String) -> String {
    let parts = today.split(separator: "-").compactMap { Int($0) }
    guard parts.count >= 2 else { return month(of: today) }
    let index = parts[0] * 12 + (parts[1] - 1) - (monthsKept - 1)
    return String(format: "%04d-%02d", index / 12, index % 12 + 1)
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

  /// `month` as this build wrote it, with every entry of an item it doesn't know carried over from `old`, the same
  /// month as iCloud holds it: an older build republishing its month must not remove a later build's items (#388).
  /// A known item is this device's own to write, so one missing from `month` stays missing.
  public static func carryingUnknown(_ month: Data, from old: Data?) -> Data {
    guard let old, let previous = (try? JSONSerialization.jsonObject(with: old)) as? [String: Any],
      var days = (try? JSONSerialization.jsonObject(with: month)) as? [String: Any]
    else { return month }
    var carried = false
    for (day, items) in previous {
      guard let items = items as? [String: Any] else { continue }
      let unknown = items.filter { DailyItem(rawValue: $0.key) == nil }
      guard !unknown.isEmpty else { continue }
      var merged = days[day] as? [String: Any] ?? [:]
      for (name, entry) in unknown where merged[name] == nil { merged[name] = entry }
      days[day] = merged
      carried = true
    }
    guard carried else { return month }
    return (try? JSONSerialization.data(withJSONObject: days, options: [.sortedKeys])) ?? month
  }

  /// How long a device handed a restore's history must send nothing before this one sends that history for it (#379).
  public static let silentDays = 30

  /// Whether a device whose newest row is `newest` (unix ms) has been silent for `silentDays` on `now`. No rows is
  /// not silence: there is nothing to send.
  public static func isSilent(newest: Int64?, now: Date) -> Bool {
    guard let newest else { return false }
    return Double(newest) < (now.timeIntervalSince1970 - Double(silentDays) * 86_400) * 1000
  }

  /// The months to write under a silent device's keys, from its peer rows here (#379): only a month where a row is
  /// absent from the key or newer than the key's, merged into the value `cloud` gives for that month (the newer change
  /// per day and item winning, unknown items carried through), with how many rows were unsent. Months older than
  /// `oldest` stay out.
  public static func unsentMonths(_ rows: [StripRow], oldest: String, cloud: (String) -> Data?) -> [String: (
    data: Data, rows: Int
  )] {
    var out: [String: (data: Data, rows: Int)] = [:]
    for (m, local) in Dictionary(grouping: rows, by: { month(of: $0.day) }) where m >= oldest {
      let old = cloud(m)
      var merged: [String: StripRow] = [:]
      for r in old.map(decode) ?? [] { merged["\(r.day)/\(r.item.rawValue)"] = r }
      var unsent = 0
      for r in local {
        let key = "\(r.day)/\(r.item.rawValue)"
        if let there = merged[key], there.updatedAt >= r.updatedAt { continue }
        merged[key] = r
        unsent += 1
      }
      guard unsent > 0, let data = encode(Array(merged.values))[m] else { continue }
      out[m] = (carryingUnknown(data, from: old), unsent)
    }
    return out
  }

  /// A monthly value back into rows. Each day and item is read on its own, so an unknown item or one malformed
  /// entry (a later build's, say) skips just that entry, not the month (Codex on #378).
  public static func decode(_ data: Data) -> [StripRow] {
    guard let days = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
    return days.flatMap { day, items -> [StripRow] in
      guard let items = items as? [String: Any] else { return [] }
      return items.compactMap { name, pair -> StripRow? in
        guard let item = DailyItem(rawValue: name), let pair = pair as? [NSNumber], pair.count == 2 else { return nil }
        return StripRow(day: day, item: item, value: max(0, pair[0].intValue), updatedAt: pair[1].int64Value)
      }
    }
  }
}
