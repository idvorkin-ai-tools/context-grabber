//  Story 271: the daily strip as archive streams, one per item (`strip.balloons`, `strip.magic`, …). A day's value
//  can change long after the day: a tap before midnight, a backdated check (#290), a counter's week edited (#342),
//  or another device's taps arriving over iCloud (#376). The Cockpit keeps the first record per (stream, guid), so
//  a record is one observation of a day, never the day itself: its guid is the day and the moment it was seen, and
//  the newest `seen_at` per day is that day's value. The cursor is the value the archive last took for each day, so
//  a run sends only the days whose merged value has changed since (the whole history the first time), and a day
//  taken back to nothing goes as 0.

import Foundation

public struct StripArchiveSource: ArchiveSource {
  let strip: DailyStrip
  let item: DailyItem
  let now: @Sendable () -> Date
  public var stream: String { ArchiveStream.strip(item) }

  public init(strip: DailyStrip, item: DailyItem, now: @escaping @Sendable () -> Date = { Date() }) {
    self.strip = strip
    self.item = item
    self.now = now
  }

  @MainActor
  public func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
    let sent = cursor.flatMap(Self.decode)
    // A cursor this build cannot read starts the stream over: the history goes again as new observations, which
    // only repeat what the archive already says.
    var taken = sent ?? [:]
    let values = try strip.values(item)
    // A day with no row any more (a sync take-back, another iCloud account's peers cleared) reads as 0, as the
    // strip shows it.
    let changed = Set(values.keys).union(taken.keys)
      .filter { (values[$0] ?? 0) != (taken[$0] ?? 0) }
      .sorted()
    let restarted = cursor != nil && sent == nil
    guard !changed.isEmpty else {
      let next = restarted ? Self.encode(taken) : cursor
      return ArchivePage(records: [], cursor: next, more: false, restarted: restarted)
    }
    let seenAt = Int64(now().timeIntervalSince1970 * 1000)
    let records = changed.prefix(limit).map { day -> [String: Any] in
      let value = values[day] ?? 0
      // 0 is what the archive assumes for a day it never heard of, so the cursor forgets it.
      taken[day] = value == 0 ? nil : value
      return [
        "guid": ArchiveGUID.stripDay(day, seenAt: seenAt), "day": day, "item": item.rawValue, "value": value,
        "seen_at": seenAt,
      ]
    }
    return ArchivePage(records: records, cursor: Self.encode(taken), more: changed.count > limit, restarted: restarted)
  }

  /// The cursor: `{"<day>": value}` for every day the archive holds above 0, as JSON.
  static func encode(_ taken: [String: Int]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: taken, options: [.sortedKeys]) else { return "{}" }
    return String(decoding: data, as: UTF8.self)
  }

  /// Nil for anything but a JSON object of whole numbers.
  static func decode(_ cursor: String) -> [String: Int]? {
    guard let object = try? JSONSerialization.jsonObject(with: Data(cursor.utf8)) as? [String: Any] else {
      return nil
    }
    var taken: [String: Int] = [:]
    for (day, value) in object {
      guard let number = value as? Int else { return nil }
      taken[day] = number
    }
    return taken
  }
}
