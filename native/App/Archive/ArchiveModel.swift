//  Story 270 (context-grabber-3il): everything the app collects goes to the Cockpit's archive on its own: the
//  trail's points and every Health sample type the mirror reads, as deltas every four hours or so (a background
//  refresh, and a foreground once that long has passed), an end-of-day batch (a background processing task), and
//  the whole history the first time, paged. Each stream's cursor (ArchiveCursorStore) moves only after a 2xx, and
//  the archive keeps one row per guid, so nothing is ever there twice. Spec:
//  docs/superpowers/specs/2026-10-19-native-stats-archive-design.md.

import BackgroundTasks
import ContextCore
import HealthKit
import UIKit

@MainActor
final class ArchiveModel {
  static let lastRunKey = "archive_last_run"
  static let deviceKey = "archive_device_id"
  /// Pages per stream in a refresh or foreground run (seconds of background time), and in the end-of-day
  /// processing task (minutes): a backfill of years of heart rate takes a few of each.
  nonisolated static let refreshPages = 20
  static let dailyPages = 200

  private let log: SessionLog
  private let database: AppDatabase
  /// Where the batches go. Nil on a simulator launched without GRABBER_ARCHIVE_URL: the simulator reaches the
  /// tailnet too, and its fixture week and imported trail must never land in Igor's archive.
  private let cockpit: String?
  private let deviceId: String
  private let health = HKHealthStore()
  private var running: Task<Void, Never>?
  private var cancelled = false

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    #if targetEnvironment(simulator)
      cockpit = environment["GRABBER_ARCHIVE_URL"]
    #else
      cockpit = environment["GRABBER_ARCHIVE_URL"] ?? CockpitPage.url
    #endif
    // The vendor id, as the strip sync uses it: a backup restored onto another phone is another device.
    let id =
      UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? database.setting(Self.deviceKey)
      ?? UUID().uuidString.lowercased()
    deviceId = id
    database.setSetting(Self.deviceKey, id)
  }

  /// Before the launch finishes (iOS refuses a handler registered later): the refresh and the end-of-day task.
  func registerBackgroundTasks() {
    let tasks = [
      (ArchiveSchedule.refreshTask, "refresh", Self.refreshPages),
      (ArchiveSchedule.dailyTask, "daily", Self.dailyPages),
    ]
    for (identifier, reason, pages) in tasks {
      let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) {
        [weak self] task in
        Task { @MainActor in self?.handle(task, reason: reason, maxPages: pages) }
      }
      if !registered { log.event("error", ["where": "archive_register", "task": identifier]) }
    }
  }

  /// At the launch's first activation: the next slots asked for, and a run if one is due.
  func launch() {
    Task { await schedule(reason: "launch") }
    runIfDue(reason: "launch")
  }

  /// A run once the interval has passed since the last one; nothing otherwise.
  func runIfDue(reason: String) {
    let last = database.setting(Self.lastRunKey).flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) }
    guard ArchiveSchedule.isDue(lastRun: last, now: Date()) else { return }
    run(reason: reason)
  }

  /// A run now, whatever the clock says (a background task, the hook); the one in flight is shared.
  @discardableResult
  func run(reason: String, maxPages: Int = ArchiveModel.refreshPages) -> Task<Void, Never> {
    if let running { return running }
    cancelled = false
    let task = Task { [weak self] in
      await self?.perform(reason: reason, maxPages: maxPages)
      self?.running = nil
    }
    running = task
    return task
  }

  /// iOS is taking the background time back: the page in flight finishes or fails on its own, nothing after it
  /// starts, and the cursor stays wherever the last 2xx put it.
  func cancel() {
    cancelled = true
    running?.cancel()
  }

  private func handle(_ task: BGTask, reason: String, maxPages: Int) {
    task.expirationHandler = { [weak self] in Task { @MainActor in self?.cancel() } }
    let active = run(reason: reason, maxPages: maxPages)
    Task { [weak self] in
      await self?.schedule(reason: reason)
      await active.value
      task.setTaskCompleted(success: self?.cancelled == false)
    }
  }

  /// Asks iOS for the next refresh and preserves a daily batch iOS has not run yet, even past midnight.
  /// The simulator has no scheduler: it says so once and runs only from the hook.
  func schedule(reason: String) async {
    #if targetEnvironment(simulator)
      log.event("archive", ["action": "schedule_skipped", "why": reason, "reason": "simulator"])
    #else
      let pending = await BGTaskScheduler.shared.pendingTaskRequests()
      let pendingDaily = pending.first { $0.identifier == ArchiveSchedule.dailyTask }
      let refresh = BGAppRefreshTaskRequest(identifier: ArchiveSchedule.refreshTask)
      refresh.earliestBeginDate = Date().addingTimeInterval(ArchiveSchedule.interval)
      var requests: [BGTaskRequest] = [refresh]
      var dailyAt = pendingDaily?.earliestBeginDate
      if reason == "daily" || pendingDaily == nil {
        let daily = BGProcessingTaskRequest(identifier: ArchiveSchedule.dailyTask)
        dailyAt = ArchiveSchedule.nextDaily(after: Date(), calendar: .current)
        daily.earliestBeginDate = dailyAt
        daily.requiresNetworkConnectivity = true
        requests.append(daily)
      }
      var submitted: [String] = []
      for request in requests {
        do {
          try BGTaskScheduler.shared.submit(request)
          submitted.append(request.identifier)
        } catch {
          log.event("error", ["where": "archive_schedule", "task": request.identifier, "message": "\(error)"])
        }
      }
      log.event(
        "archive",
        [
          "action": "scheduled", "why": reason, "tasks": submitted,
          "daily_at": dailyAt.map { ISO8601DateFormatter().string(from: $0) } ?? "pending",
        ])
    #endif
  }

  private func perform(reason: String, maxPages: Int) async {
    guard let cockpit else {
      log.event("archive", ["action": "skipped", "why": reason, "reason": "no archive URL on the simulator"])
      return
    }
    guard let cursors = database.archiveCursors else {
      log.event("error", ["where": "archive_run", "message": "no database"])
      return
    }
    let started = Date()
    var sources: [ArchiveSource] = []
    if let locations = database.locations { sources.append(LocationArchiveSource(store: locations)) }
    var locked = !UIApplication.shared.isProtectedDataAvailable
    if locked {
      log.event("archive", ["action": "health_skipped", "why": reason, "reason": "phone locked"])
    } else {
      sources += await healthSources()
    }
    var uploader = ArchiveUploader(cursors: cursors, cockpit: cockpit, deviceId: deviceId) {
      try await URLSession.shared.data(for: $0)
    }
    uploader.maxPages = maxPages
    var pages = 0
    var records = 0
    var inserted = 0
    var duplicate = 0
    var stopped: [String: String] = [:]
    for source in sources {
      if cancelled {
        stopped[source.stream] = "cancelled"
        break
      }
      let report = await uploader.upload(source) { [log] type, fields in
        log.event(type, fields.merging(["why": reason]) { $1 })
      }
      pages += report.pages
      records += report.records
      inserted += report.inserted
      duplicate += report.duplicate
      if let why = report.stopped { stopped[source.stream] = why }
      // The Cockpit is away: every stream after this one would fail the same way.
      if report.stopped == "retry" { break }
      if report.stopped == "read" && !UIApplication.shared.isProtectedDataAvailable {
        locked = true
        log.event("archive", ["action": "health_skipped", "why": reason, "reason": "phone locked"])
        break
      }
    }
    if !cancelled && !locked {
      database.setSetting(Self.lastRunKey, String(Int64(started.timeIntervalSince1970 * 1000)))
    }
    log.event(
      "archive_run",
      [
        "why": reason, "streams": sources.count, "pages": pages, "records": records, "inserted": inserted,
        "duplicate": duplicate, "stopped": stopped, "ms": Int(Date().timeIntervalSince(started) * 1000),
      ])
  }

  /// One stream per type the mirror reads, only once Health has been asked about all of them (Today asks; an
  /// archive run never puts Health's sheet up). A type Igor denied answers nothing, and that is its archive.
  private func healthSources() async -> [ArchiveSource] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    let status: HKAuthorizationRequestStatus
    do {
      status = try await health.statusForAuthorizationRequest(toShare: [], read: HealthKitSource.readTypes)
    } catch {
      log.event("error", ["where": "archive_health_status", "message": "\(error)"])
      return []
    }
    guard status == .unnecessary else {
      log.event("archive", ["action": "health_skipped", "reason": "not asked yet: Today asks"])
      return []
    }
    return HealthKitSource.readTypes.compactMap { $0 as? HKSampleType }
      .sorted { $0.identifier < $1.identifier }
      .map { HealthArchiveSource(store: health, type: $0) }
  }
}
