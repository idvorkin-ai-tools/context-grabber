//  The day, summed up, to Larry (stories 1611-1613; spec 2026-11-24-daily-summary-to-larry-design.md): after every
//  grab the week's seven days are worked out again from the grab, the trail's places by name and the strip, each day
//  that says something new is queued, and what is due goes to the Cockpit's `POST /daily`. Only the iPhone sends: it
//  has Health, and its strip already holds the iPad's taps. A Cockpit that doesn't answer is tried again after half a
//  minute, then longer each time up to ten minutes, and whenever the app comes to the front.

import ContextCore
import Foundation
import UIKit

@MainActor
final class DailyPushModel: ObservableObject {
  static let stateKey = "daily_push"
  /// The switch, on unless turned off (Igor: "we should have it all tracked").
  static let onKey = "daily_push_on"

  @Published private(set) var on: Bool
  @Published private(set) var lastSentDate: String?
  @Published private(set) var lastSentAt: Double?
  @Published private(set) var waitingCount = 0

  private let log: SessionLog
  private let database: AppDatabase
  /// Nil where nothing is sent: the iPad, the Mac, and a simulator without GRABBER_ARCHIVE_URL (its fixture week must
  /// never reach Igor's Cockpit), by the archive's own rule.
  private let sender: DailyPushSender?
  private let device: String
  private var state = DailyPushState()
  private var sending: Task<Void, Never>?
  private var retry: Task<Void, Never>?
  private var retryDelay: Double = 30
  /// Bumped by the switch: a send that started before it lands on nothing.
  private var generation = 0

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    on = database.setting(Self.onKey) != "0"
    device =
      database.setting(ArchiveModel.deviceKey) ?? UIDevice.current.identifierForVendor?.uuidString.lowercased()
      ?? "unknown"
    let phone = UIDevice.current.userInterfaceIdiom == .phone && !ProcessInfo.processInfo.isiOSAppOnMac
    if phone, let cockpit = ArchiveModel.destination(environment) {
      sender = DailyPushSender(cockpit: cockpit, transport: { try await URLSession.shared.data(for: $0) })
    } else {
      sender = nil
    }
    if let raw = database.setting(Self.stateKey) {
      do {
        state = try JSONDecoder().decode(DailyPushState.self, from: Data(raw.utf8))
      } catch {
        log.event("error", ["where": "daily_push_state", "message": "\(error)"])
      }
    }
    published()
  }

  /// Whether this device sends at all (the iPhone with a Cockpit to send to).
  var sends: Bool { sender != nil }

  func setOn(_ value: Bool) {
    guard value != on else { return }
    on = value
    database.setSetting(Self.onKey, value ? "1" : "0")
    log.event("daily_push", ["action": "switch", "on": value, "dropped": value ? 0 : state.waiting.count])
    generation += 1
    sending?.cancel()
    sending = nil
    retry?.cancel()
    // Off drops what waited; on checks the week afresh at the next grab.
    state = DailyPushState()
    save()
  }

  /// A grab finished: work the week out again and send what changed.
  func afterGrab(_ snap: MirrorSnapshot) {
    guard on, sends else { return }
    let clock = LocalClock()
    let now = Geo.ms(Date())
    do {
      let named = Set(try database.locations?.knownPlaces().map(\.name) ?? [])
      let places = try placesByDay(now: now)
      var strip: [DailyItem: [String: Int]] = [:]
      for item in DailyItem.allCases { strip[item] = try database.dailyStrip?.values(item) ?? [:] }
      let activity = try database.activityLog?.entries(since: Date().addingTimeInterval(-9 * 24 * 3600)) ?? []
      let records = DailyPush.week(
        snap, places: places, namedPlaces: named, strip: strip, activity: activity,
        today: AccessoryLog.dateKey(Date())
      ).map {
        DailyPush.record($0, device: device, build: BuildInfo.sha, now: now, clock: clock)
      }
      let queued = state.consider(records)
      if !queued.isEmpty { log.event("daily_push", ["action": "queued", "dates": queued]) }
      save()
    } catch {
      log.event("error", ["where": "daily_push_build", "message": "\(error)"])
      return
    }
    send(reason: "grab")
  }

  func foreground() {
    guard on, sends else { return }
    send(reason: "foreground")
  }

  /// The week's places by local day, from the trail: names and minutes only ever leave.
  private func placesByDay(now: Double) throws -> [String: PlaceDaySummary] {
    guard let store = database.locations else { return [:] }
    let points = try store.points(since: now - 8 * 24 * 3_600_000)
    let clusters = StayClustering.cluster(points, knownPlaces: try store.knownPlaces())
    let days = PlacesDaily.build(stays: clusters.stays, points: points, days: 7, now: now)
    return Dictionary(days.map { ($0.dateKey, $0) }, uniquingKeysWith: { a, _ in a })
  }

  private func send(reason: String) {
    guard let sender, on, sending == nil, !state.waiting.isEmpty else { return }
    retry?.cancel()
    let start = state
    let log = self.log
    let today = AccessoryLog.dateKey(Date())
    let generation = self.generation
    sending = Task {
      let result = await sender.send(start, today: today) { name, fields in
        var fields = fields
        fields["trigger"] = reason
        log.event(name, fields)
      }
      guard generation == self.generation else { return }
      merge(sent: start, into: result.state)
      sending = nil
      if result.ended == .retry {
        scheduleRetry()
      } else {
        retryDelay = 30
        // Today held back by the fifteen minutes: try again once they are up.
        if !state.waiting.isEmpty { scheduleRetry(after: DailyPush.todayEveryMs / 1000) }
      }
    }
  }

  /// Only the sending moves: a day queued while it ran keeps waiting.
  private func merge(sent start: DailyPushState, into after: DailyPushState) {
    var merged = after
    for record in state.waiting where !start.waiting.contains(record) {
      merged.consider([record])
    }
    state = merged
    save()
  }

  private func scheduleRetry(after seconds: Double? = nil) {
    let delay = seconds ?? retryDelay
    if seconds == nil { retryDelay = min(retryDelay * 2, 600) }
    retry?.cancel()
    retry = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.send(reason: "retry")
    }
  }

  private func save() {
    published()
    do {
      let raw = try JSONEncoder().encode(state)
      database.setSetting(Self.stateKey, String(decoding: raw, as: UTF8.self))
    } catch {
      log.event("error", ["where": "daily_push_save", "message": "\(error)"])
    }
  }

  private func published() {
    lastSentDate = state.lastSentDate
    lastSentAt = state.lastSentAt
    waitingCount = state.waiting.count
  }

  /// Settings' line under the switch.
  var statusLine: String {
    guard sends else { return "Only the iPhone sends the day." }
    guard on else { return "Off: nothing is sent." }
    var parts: [String] = []
    if let date = lastSentDate, let at = lastSentAt {
      let time = DateFormatter.localizedString(
        from: Date(timeIntervalSince1970: at / 1000), dateStyle: .none, timeStyle: .short)
      parts.append("Last sent \(date) at \(time)")
    } else {
      parts.append("Nothing sent yet")
    }
    if waitingCount > 0 { parts.append("\(waitingCount) waiting") }
    return parts.joined(separator: " · ")
  }
}
