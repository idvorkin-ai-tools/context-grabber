//  The day, summed up, to Larry (stories 1611-1613; spec 2026-11-24-daily-summary-to-larry-design.md): one record
//  per local day of the grab's week, built from what Today already reads (the week's series, the nights, the
//  workouts), the day's places by name and the strip's habits. The wire is the shape agreed with Larry on
//  2026-11-24 (Cockpit thread igor2-88g.1620, msgs cc-lane-pushstats-shape and 567ab576db57): `POST /daily`, one
//  record per request, its id the device, the day and a hash of what it says, so an unchanged day is the same id
//  and a resend is a duplicate. The Cockpit keeps the newest `computed_at` per (device, date).

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// One habit on the strip, as the day's record carries it.
public struct DailyPushHabit: Equatable, Sendable {
  public var name: String
  /// A check: done or not. Nil for a counter.
  public var done: Bool?
  /// A counter: how many. Nil for a check.
  public var count: Int?
  /// What made a check count: "tap", "gym_timer", "breathing", "health". Empty when not done.
  public var by: [String]

  public init(name: String, done: Bool? = nil, count: Int? = nil, by: [String] = []) {
    self.name = name
    self.done = done
    self.count = count
    self.by = by
  }
}

/// What one local day's record is made from.
public struct DailyPushDay: Equatable, Sendable {
  public var date: String
  public var steps: Double?
  public var exerciseMinutes: Double?
  public var activeEnergy: Double?
  public var walkingKm: Double?
  /// Kilograms.
  public var weightKg: Double?
  public var mindfulMinutes: Double?
  public var heartRate: HeartRateDaily?
  public var restingHeartRate: HeartRateDaily?
  public var hrv: HeartRateDaily?
  /// The night that began at noon on `date`, all sources merged.
  public var sleep: SleepDaily?
  public var workouts: [WorkoutEntry] = []
  public var places: PlaceDaySummary?
  /// The names of Igor's known places: a stay at any other place counts only as minutes.
  public var namedPlaces: Set<String> = []
  public var habits: [DailyPushHabit] = []

  public init(date: String) { self.date = date }
}

public enum DailyPush {
  /// Today's record goes at most this often; a past day as soon as it changes.
  public static let todayEveryMs = 15 * 60 * 1000.0
  /// A day still waiting after this long is dropped: it has left the week, and the archive has its samples.
  public static let maxWaitMs = 8 * 24 * 60 * 60 * 1000.0

  /// Where a night's sleep was measured: "watch", "phone", "manual", "other", or "mixed" when more than one, nil
  /// with no samples. Hours in bed over-read when no Watch was worn, so Larry needs to know (msg 567ab576db57).
  public static func sleepSource(_ night: SleepDaily) -> String? {
    let kinds = Set(night.samples.compactMap { $0.source }.map(sourceKind))
    if kinds.isEmpty { return nil }
    return kinds.count == 1 ? kinds.first : "mixed"
  }

  static func sourceKind(_ name: String) -> String {
    let n = name.lowercased()
    if n.contains("watch") { return "watch" }
    if n.contains("iphone") || n.contains("phone") { return "phone" }
    if n == "health" || n.contains("manual") { return "manual" }
    return "other"
  }

  /// The week's days from a grab, today last. `places` by date key; each day's habits from the strip and the activity.
  public static func week(
    _ snap: MirrorSnapshot, places: [String: PlaceDaySummary], namedPlaces: Set<String>,
    strip: [DailyItem: [String: Int]], activity: [ActivityEntry], today: String
  ) -> [DailyPushDay] {
    let data = snap.weeklyData
    let dates = (snap.weekly[.steps]?.dates ?? data.sleep.map(\.date)).sorted()
    let nights = Dictionary((snap.sleepBundle?.merged ?? []).map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
    func value(_ series: [DailyValue], _ date: String) -> Double? { series.first { $0.date == date }?.value }
    func ranged(_ series: [HeartRateDaily], _ date: String) -> HeartRateDaily? { series.first { $0.date == date } }
    return dates.map { date in
      var day = DailyPushDay(date: date)
      day.steps = value(data.steps, date)
      day.exerciseMinutes = value(data.exerciseMinutes, date)
      day.activeEnergy = value(data.activeEnergy, date)
      day.walkingKm = value(data.walkingDistance, date)
      day.weightKg = value(data.weight, date)
      day.mindfulMinutes = value(data.meditation, date)
      day.heartRate = ranged(data.heartRate, date)
      day.restingHeartRate = ranged(data.restingHeartRate, date)
      day.hrv = ranged(data.hrv, date)
      day.sleep = nights[date]
      day.workouts = snap.workoutsByDay[date] ?? []
      day.places = places[date]
      day.namedPlaces = namedPlaces
      day.habits = habits(
        date: date, strip: strip, activity: activity, workouts: day.workouts, mindfulMinutes: day.mindfulMinutes,
        today: today)
      return day
    }
  }

  /// The strip's habits for one day: a check's value and what made it count, a counter's count. As on the strip,
  /// Health's mindful minutes make meditation count only for today.
  public static func habits(
    date: String, strip: [DailyItem: [String: Int]], activity: [ActivityEntry], workouts: [WorkoutEntry],
    mindfulMinutes: Double?, today: String
  ) -> [DailyPushHabit] {
    DailyItem.allCases.map { item in
      let tapped = (strip[item]?[date] ?? 0) > 0
      if item.isCounter { return DailyPushHabit(name: item.rawValue, count: strip[item]?[date] ?? 0) }
      var by: [String] = tapped ? ["tap"] : []
      switch item {
      case .gym:
        if activity.contains(where: { $0.kind == .gymTimer && $0.dateKey == date }) { by.append("gym_timer") }
        if workouts.contains(where: { DailyStrip.strengthWorkouts.contains($0.activityType) }) { by.append("health") }
      case .meditation:
        if activity.contains(where: { $0.kind == .breathing && $0.dateKey == date }) { by.append("breathing") }
        if date == today, let m = mindfulMinutes, m > 0 { by.append("health") }
      default: break
      }
      return DailyPushHabit(name: item.rawValue, done: !by.isEmpty, by: by)
    }
  }

  /// The record's content: everything but the id and the times it was worked out and sent, which the hash covers.
  public static func content(_ day: DailyPushDay, device: String, final: Bool, timeZone: TimeZone) -> JSValue {
    func iso(_ ms: Double) -> JSValue { .string(LiveContextWire.iso(ms, timeZone)) }
    func isoText(_ text: String?) -> JSValue { isoMs(text).map(iso) ?? .null }
    let sleep: JSValue =
      day.sleep.map { night in
        var inBed: Double?
        if let bed = isoMs(night.bedtime), let wake = isoMs(night.wakeTime), wake > bed {
          inBed = round1((wake - bed) / 3_600_000)
        }
        return .object([
          ("night_of", .string(night.date)), ("asleep_h", .num(night.totalHours)), ("in_bed_h", .num(inBed)),
          ("awake_h", .number(round1(night.awakeHours))), ("core_h", .number(round1(night.coreHours))),
          ("deep_h", .number(round1(night.deepHours))), ("rem_h", .number(round1(night.remHours))),
          ("bedtime", isoText(night.bedtime)), ("wake", isoText(night.wakeTime)), ("nap", .bool(night.isNap)),
          ("asleep_source", sleepSource(night).map { .string($0) } ?? .null),
        ])
      } ?? .null
    let workouts: JSValue = .array(
      day.workouts.map { w in
        .object([
          ("type", .string(w.activityType)), ("start", isoText(w.startTime)), ("end", isoText(w.endTime)),
          ("minutes", .number(w.durationMinutes)), ("kcal", .num(w.energyBurned)), ("km", .num(w.distanceKm)),
        ])
      })
    let health: JSValue = .object([
      ("sleep", sleep), ("steps", .num(day.steps)), ("exercise_min", .num(day.exerciseMinutes)),
      ("active_kcal", .num(day.activeEnergy)), ("walk_km", .num(day.walkingKm)),
      ("hr_avg_bpm", .num(day.heartRate?.avg)), ("hr_min_bpm", .num(day.heartRate?.min)),
      ("hr_max_bpm", .num(day.heartRate?.max)), ("resting_hr_bpm", .num(day.restingHeartRate?.avg)),
      ("hrv_ms", .num(day.hrv?.avg)), ("weight_kg", .num(day.weightKg)), ("mindful_min", .num(day.mindfulMinutes)),
      ("workouts", workouts),
    ])
    let places: JSValue =
      day.places.map { summary in
        let named = { (id: String) in day.namedPlaces.contains(id) }
        let visits = summary.visits.filter { named($0.placeId) }
        let unnamed = summary.places.filter { !named($0.placeId) }.reduce(0) { $0 + $1.totalMinutes }
        return .object([
          (
            "visits",
            .array(
              visits.map {
                .object([
                  ("place", .string($0.placeId)), ("start", iso($0.startTime)), ("end", iso($0.endTime)),
                  ("minutes", .int($0.durationMinutes)),
                ])
              })
          ),
          (
            "totals",
            .array(
              summary.places.filter { named($0.placeId) }.map {
                .object([("place", .string($0.placeId)), ("minutes", .int($0.totalMinutes))])
              })
          ),
          ("unnamed_min", .int(unnamed)), ("transit_min", .int(summary.transitMinutes)),
          ("no_data_min", .int(summary.noDataMinutes)),
        ])
      } ?? .null
    let habits: JSValue = .object(
      day.habits.map { h in
        if let count = h.count { return (h.name, .object([("count", .int(count))])) }
        return (h.name, .object([("done", .bool(h.done ?? false)), ("by", .array(h.by.map { .string($0) }))]))
      })
    return .object([
      ("type", .string("day")), ("device", .string(device)), ("date", .string(day.date)),
      ("tz", .string(timeZone.identifier)), ("final", .bool(final)), ("health", health), ("places", places),
      ("habits", habits),
    ])
  }

  /// A day is final once it and its night's sleep can no longer change: from noon on the next day.
  public static func isFinal(_ date: String, now: Double, clock: LocalClock) -> Bool {
    let midnight = clock.midnight(date)
    guard !midnight.isNaN, let next = clock.calendar.date(byAdding: .day, value: 1, to: jsDate(midnight)) else {
      return false
    }
    return now >= clock.setHours(jsMillis(next), 12)
  }

  /// One day's record, ready to queue.
  public static func record(
    _ day: DailyPushDay, device: String, build: String, now: Double, clock: LocalClock
  ) -> DailyPushRecord {
    let content = content(
      day, device: device, final: isFinal(day.date, now: now, clock: clock), timeZone: clock.calendar.timeZone)
    let text = content.stringify()
    let hash = fnv(text)
    guard case .object(var fields) = content else { preconditionFailure("content is an object") }
    fields.insert(("id", .string("\(device)-\(day.date)-\(hash)")), at: 0)
    fields.append(("computed_at", .string(LiveContextWire.iso(now, clock.calendar.timeZone))))
    fields.append(("build", .string(build)))
    return DailyPushRecord(date: day.date, hash: hash, json: JSValue.object(fields).stringify(), computedAt: now)
  }

  /// FNV-1a, 64 bits, the first 12 hex digits: the same content gives the same id on every build and platform.
  static func fnv(_ text: String) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 {
      h ^= UInt64(byte)
      h = h &* 0x0000_0100_0000_01b3
    }
    return String(String(format: "%016llx", h).prefix(12))
  }

  /// `isoString`'s output (milliseconds, Z) or a plain ISO 8601 time, as UTC unix ms.
  static func isoMs(_ text: String?) -> Double? {
    guard let text else { return nil }
    let withMs = ISO8601DateFormatter()
    withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = withMs.date(from: text) ?? ISO8601DateFormatter().date(from: text) else { return nil }
    return Geo.ms(date)
  }
}

/// One day's record as queued: the body without `sent_at`, which goes on at send time.
public struct DailyPushRecord: Equatable, Sendable, Codable {
  public var date: String
  public var hash: String
  public var json: String
  public var computedAt: Double
}

/// What waits and what the Cockpit has taken, kept between launches.
public struct DailyPushState: Equatable, Sendable, Codable {
  /// Oldest day first; at most one per day, the newest.
  public var waiting: [DailyPushRecord] = []
  /// The hash the Cockpit last took for each day.
  public var sentHash: [String: String] = [:]
  /// When each day last went (UTC unix ms).
  public var sentAt: [String: Double] = [:]
  public var lastSentDate: String?
  public var lastSentAt: Double?

  public init() {}

  /// The week's records after a grab: a day the Cockpit already has as it is now leaves the queue; a day that says
  /// something new replaces whatever of it waited. Returns the days queued.
  @discardableResult
  public mutating func consider(_ records: [DailyPushRecord]) -> [String] {
    var queued: [String] = []
    for record in records {
      if sentHash[record.date] == record.hash {
        waiting.removeAll { $0.date == record.date }
        continue
      }
      if let i = waiting.firstIndex(where: { $0.date == record.date }) {
        if waiting[i].hash == record.hash { continue }
        waiting[i] = record
      } else {
        waiting.append(record)
      }
      queued.append(record.date)
    }
    waiting.sort { $0.date < $1.date }
    return queued
  }

  /// What may go now: every waiting day, but today only if it last went more than fifteen minutes ago.
  public func due(now: Double, today: String) -> [DailyPushRecord] {
    waiting.filter { record in
      guard record.date == today, let last = sentAt[today] else { return true }
      return now - last >= DailyPush.todayEveryMs
    }
  }

  /// Takes out what has waited past the week.
  public mutating func dropStale(now: Double) -> [DailyPushRecord] {
    let stale = waiting.filter { now - $0.computedAt > DailyPush.maxWaitMs }
    waiting.removeAll { now - $0.computedAt > DailyPush.maxWaitMs }
    return stale
  }

  mutating func taken(_ record: DailyPushRecord, at now: Double) {
    waiting.removeAll { $0.date == record.date && $0.hash == record.hash }
    sentHash[record.date] = record.hash
    sentAt[record.date] = now
    lastSentDate = record.date
    lastSentAt = now
    // Only the week is remembered: older days can no longer change.
    let keep = Set(sentHash.keys.sorted().suffix(14))
    sentHash = sentHash.filter { keep.contains($0.key) }
    sentAt = sentAt.filter { keep.contains($0.key) }
  }

  mutating func refused(_ record: DailyPushRecord) {
    waiting.removeAll { $0.date == record.date && $0.hash == record.hash }
    // Not again until it changes.
    sentHash[record.date] = record.hash
  }
}

public enum DailyPushWire {
  public static let notYet = "The Cockpit does not take day records yet"

  public static func request(_ record: DailyPushRecord, cockpit: String, sentAt: Double, timeZone: TimeZone) throws
    -> URLRequest
  {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    guard var body = try JSONSerialization.jsonObject(with: Data(record.json.utf8)) as? [String: Any] else {
      throw URLError(.cannotParseResponse)
    }
    body["sent_at"] = LiveContextWire.iso(sentAt, timeZone)
    var request = URLRequest(url: base.appendingPathComponent("daily"))
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
  }

  /// As `/context` answers: a 2xx with ok is taken, a 404 or 405 is "not yet", another 4xx is refused, else retried.
  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> LiveContextWire.Outcome {
    let outcome = LiveContextWire.outcome(status: status, body: body, error: error)
    if case .retry(let reason) = outcome, reason.hasPrefix(LiveContextWire.notYet) {
      return .retry(reason: notYet + reason.dropFirst(LiveContextWire.notYet.count))
    }
    return outcome
  }
}

/// Sends what is due, oldest day first, and logs each answer as a `daily_push` line. Stops at the first retry.
public struct DailyPushSender: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  /// How a send ended, for the app's backoff.
  public enum Ended: Equatable, Sendable { case done, retry }

  let cockpit: String
  let timeZone: TimeZone
  let transport: Transport

  public init(cockpit: String, timeZone: TimeZone = .current, transport: @escaping Transport) {
    self.cockpit = cockpit
    self.timeZone = timeZone
    self.transport = transport
  }

  public func send(
    _ start: DailyPushState, today: String, now: @Sendable () -> Date = Date.init,
    log: (String, [String: Any]) -> Void
  ) async -> (state: DailyPushState, ended: Ended) {
    var state = start
    for record in state.dropStale(now: Geo.ms(now())) {
      log("daily_push", ["action": "dropped", "date": record.date, "reason": "waited past the week"])
    }
    for record in state.due(now: Geo.ms(now()), today: today) {
      guard !Task.isCancelled else { return (state, .done) }
      let sentAt = Geo.ms(now())
      var fields: [String: Any] = ["date": record.date, "hash": record.hash]
      let outcome: LiveContextWire.Outcome
      do {
        let request = try DailyPushWire.request(record, cockpit: cockpit, sentAt: sentAt, timeZone: timeZone)
        let (data, response) = try await transport(request)
        outcome = DailyPushWire.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
      } catch {
        if Task.isCancelled { return (state, .done) }
        if CockpitReach.isAway(error) { fields["unreachable"] = true }
        outcome = DailyPushWire.outcome(status: nil, body: nil, error: error.localizedDescription)
      }
      switch outcome {
      case .sent(let duplicate):
        state.taken(record, at: sentAt)
        fields["action"] = "sent"
        if duplicate { fields["duplicate"] = true }
        log("daily_push", fields)
      case .refused(let status, let reason):
        state.refused(record)
        fields["action"] = "refused"
        fields["status"] = status
        fields["reason"] = reason
        log("daily_push", fields)
      case .retry(let reason):
        fields["action"] = "waiting"
        fields["reason"] = reason
        fields["count"] = state.waiting.count
        log("daily_push", fields)
        return (state, .retry)
      }
    }
    return (state, .done)
  }
}
