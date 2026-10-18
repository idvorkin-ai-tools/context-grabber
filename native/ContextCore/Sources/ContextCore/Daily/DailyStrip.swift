//  The daily strip (#236, #238; home-screen spec, "The daily strip"): gym and journal checks and the balloon and
//  magic counts, one value per item per LOCAL day, kept so the week can be read later. Gym also counts a day the
//  Gym Timer finished a workout or Health has a strength workout, and says how many days since the last.

import Foundation

public enum DailyItem: String, CaseIterable, Sendable {
  case gym, meditation, journal, balloons, magic

  public var isCounter: Bool { self == .balloons || self == .magic }
}

public struct DailyStrip {
  private let db: SQLiteDatabase

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS daily_strip (
        date_key TEXT NOT NULL,
        item     TEXT NOT NULL,
        value    INTEGER NOT NULL,
        PRIMARY KEY (date_key, item)
      );
      """)
    // #376: when each value changed, so a check's latest change wins across devices; 0 for the rows from before.
    let columns = try db.run("PRAGMA table_info(daily_strip)").compactMap { $0["name"]?.textValue }
    if !columns.contains("updated_at") {
      try db.execute("ALTER TABLE daily_strip ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0;")
    }
    // #376: the other devices' values, as their iCloud keys last said.
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS daily_strip_peers (
        device     TEXT NOT NULL,
        date_key   TEXT NOT NULL,
        item       TEXT NOT NULL,
        value      INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (device, date_key, item)
      );
      """)
  }

  /// The day's value across devices (#376): counts add up, a check is its latest change. 0 with nothing recorded.
  public func value(_ item: DailyItem, day: String) throws -> Int {
    try merged(item, day: day)[day] ?? 0
  }

  /// This device's own value, which a counter's step starts from.
  public func ownValue(_ item: DailyItem, day: String) throws -> Int {
    let rows = try db.run(
      "SELECT value FROM daily_strip WHERE date_key = ? AND item = ?", [.text(day), .text(item.rawValue)])
    return Int(rows.first?["value"]?.intValue ?? 0)
  }

  public func set(_ item: DailyItem, day: String, value: Int, at: Date = Date()) throws {
    _ = try db.run(
      """
      INSERT INTO daily_strip (date_key, item, value, updated_at) VALUES (?, ?, ?, ?)
      ON CONFLICT(date_key, item) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
      """,
      [.text(day), .text(item.rawValue), .int(Int64(max(0, value))), .int(Int64(at.timeIntervalSince1970 * 1000))])
  }

  /// The days the item was above 0 across devices, any age.
  public func days(_ item: DailyItem) throws -> Set<String> {
    Set(try merged(item, day: nil).filter { $0.value > 0 }.keys)
  }

  // MARK: Sync (#376)

  /// This device's rows, every day or one month's (`yyyy-mm`).
  public func ownRows(month: String? = nil) throws -> [StripRow] {
    let rows = try db.run(
      "SELECT date_key, item, value, updated_at FROM daily_strip" + (month == nil ? "" : " WHERE date_key LIKE ?"),
      month.map { [.text($0 + "-%")] } ?? [])
    return rows.compactMap(StripRow.init(row:))
  }

  /// Another device's rows for one month, as its key now says: what was there for that month is replaced.
  public func replacePeer(_ device: String, month: String, rows: [StripRow]) throws {
    _ = try db.run(
      "DELETE FROM daily_strip_peers WHERE device = ? AND date_key LIKE ?", [.text(device), .text(month + "-%")])
    for r in rows where r.day.hasPrefix(month + "-") {
      _ = try db.run(
        "INSERT OR REPLACE INTO daily_strip_peers (device, date_key, item, value, updated_at) VALUES (?, ?, ?, ?, ?)",
        [.text(device), .text(r.day), .text(r.item.rawValue), .int(Int64(r.value)), .int(r.updatedAt)])
    }
  }

  /// This install's rows become `device`'s peer rows and this install starts empty: a restore brought another
  /// phone's history, which that phone's own keys carry (Codex on #378). Returns how many rows moved.
  @discardableResult
  public func handOver(to device: String) throws -> Int {
    let rows = try ownRows()
    try db.execute("BEGIN")
    do {
      for r in rows {
        _ = try db.run(
          "INSERT OR REPLACE INTO daily_strip_peers (device, date_key, item, value, updated_at) VALUES (?, ?, ?, ?, ?)",
          [.text(device), .text(r.day), .text(r.item.rawValue), .int(Int64(r.value)), .int(r.updatedAt)])
      }
      try db.execute("DELETE FROM daily_strip;")
      try db.execute("COMMIT")
    } catch {
      try? db.execute("ROLLBACK")
      throw error
    }
    return rows.count
  }

  /// Every other device's rows gone: the iCloud account changed (Codex on #378). The devices in `keeping` were
  /// handed this install's own history, which no store may hold, so their rows stay.
  public func clearPeers(keeping: Set<String> = []) throws {
    guard !keeping.isEmpty else { return try db.execute("DELETE FROM daily_strip_peers;") }
    _ = try db.run(
      "DELETE FROM daily_strip_peers WHERE device NOT IN (" + keeping.map { _ in "?" }.joined(separator: ", ") + ")",
      keeping.sorted().map { .text($0) })
  }

  private func merged(_ item: DailyItem, day: String?) throws -> [String: Int] {
    let filter = day == nil ? "item = ?" : "item = ? AND date_key = ?"
    let args: [SQLiteValue] = [.text(item.rawValue)] + (day.map { [.text($0)] } ?? [])
    let own = try db.run("SELECT date_key, item, value, updated_at FROM daily_strip WHERE " + filter, args)
    let peers = try db.run("SELECT date_key, item, value, updated_at FROM daily_strip_peers WHERE " + filter, args)
    return StripRow.merge((own + peers).compactMap(StripRow.init(row:)), item: item)
  }

  // MARK: Gym days

  /// Health's names for a gym session (`Health.workoutActivityName`).
  public static let strengthWorkouts: Set<String> = ["Strength Training", "Functional Strength"]

  /// Every day that counts as a gym day: tapped, a finished Gym Timer workout, or a strength workout in Health.
  public static func gymDays(
    tapped: Set<String>, timer: [ActivityEntry], workoutsByDay: [String: [WorkoutEntry]]
  ) -> Set<String> {
    var days = tapped
    days.formUnion(timer.filter { $0.kind == .gymTimer }.map(\.dateKey))
    for (day, workouts) in workoutsByDay where workouts.contains(where: { strengthWorkouts.contains($0.activityType) })
    {
      days.insert(day)
    }
    return days
  }

  // MARK: Meditation (#257)

  /// Where today's meditation came from without a tap: "breathing" (a Box breathing session reached Done today),
  /// "health" (the last grab, made today, had mindful minutes), or nil.
  public static func meditationSource(
    today: String, activity: [ActivityEntry], healthMinutes: Double?, healthDay: String?
  ) -> String? {
    if activity.contains(where: { $0.kind == .breathing && $0.dateKey == today }) { return "breathing" }
    if healthDay == today, let minutes = healthMinutes, minutes > 0 { return "health" }
    return nil
  }

  /// Every day meditation counts for days since (2026-10-17): a tap, or a Box breathing session that reached Done.
  /// Health's mindful minutes say only whether today counts (`meditationSource`), so they are not here.
  public static func meditationDays(tapped: Set<String>, activity: [ActivityEntry]) -> Set<String> {
    tapped.union(activity.filter { $0.kind == .breathing }.map(\.dateKey))
  }

  /// Days from the newest gym day on or before `today` to today: 0 when today counts, nil with none ever.
  public static func daysSince(_ days: Set<String>, today: String, calendar: Calendar = .current) -> Int? {
    guard let last = days.filter({ $0 <= today }).max(), let from = date(last, calendar), let to = date(today, calendar)
    else { return nil }
    return calendar.dateComponents([.day], from: from, to: to).day
  }

  /// #290: how far back an earlier day can be marked.
  public static let backdateRange = 0...14

  /// The day `daysAgo` days before `today`, as a date key; nil for a malformed `today`.
  public static func day(_ daysAgo: Int, before today: String, calendar: Calendar = .current) -> String? {
    guard let to = date(today, calendar), let d = calendar.date(byAdding: .day, value: -daysAgo, to: to) else {
      return nil
    }
    let c = calendar.dateComponents([.year, .month, .day], from: d)
    guard let y = c.year, let m = c.month, let dd = c.day else { return nil }
    return String(format: "%04d-%02d-%02d", y, m, dd)
  }

  /// The slider's label: "today · Tue, Oct 13", "yesterday · Mon, Oct 12", "3 days ago · Sat, Oct 10".
  public static func backdateLabel(_ daysAgo: Int, today: String, calendar: Calendar = .current) -> String {
    let words = daysAgo == 0 ? "today" : daysAgo == 1 ? "yesterday" : "\(daysAgo) days ago"
    guard let key = day(daysAgo, before: today, calendar: calendar), let d = date(key, calendar) else { return words }
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, MMM d"
    return "\(words) \u{00B7} \(f.string(from: d))"
  }

  private static func date(_ key: String, _ calendar: Calendar) -> Date? {
    let p = key.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
  }
}
