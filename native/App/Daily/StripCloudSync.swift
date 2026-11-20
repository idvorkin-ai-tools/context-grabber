//  #376, story 153: the daily strip on every device signed into Igor's iCloud, through the iCloud key-value store
//  (plan 2026-10-17-strip-sync-plan.md). This device writes only its own monthly keys; the other devices' keys are
//  read into `daily_strip_peers`, and the strip shows the merge. Without iCloud the store holds values locally and
//  nothing arrives, so the strip works as before on this device alone.

import ContextCore
import Foundation
import Network
import UIKit

@MainActor
final class StripCloudSync {
  private let store = NSUbiquitousKeyValueStore.default
  private let strip: DailyStrip
  private let device: String
  /// The ids this install handed its history to: an account change keeps their rows.
  private let handedOver: Set<String>
  private let log: SessionLog
  private let database: AppDatabase
  /// #380: closed until this database has seen iCloud's first sync (a reinstall's empty months would overwrite the
  /// ones in iCloud), and again after a recovery of its own iCloud months fails until one succeeds (#384).
  private var gate: StripPublishGate
  private var ready: Bool { gate.ready }
  private var pendingMonths: Set<String> = []
  /// While waiting: five minutes online with no download means iCloud holds nothing for this device (Codex on #378).
  private var path: NWPathMonitor?
  private var quiet: Task<Void, Never>?
  /// An arrival may be part of the download, so the wait ends only after a quiet minute online (#388, option A).
  private var wait = StripFirstSyncWait()
  /// Counter steps made before the first sync, each saved with its counter write as one (local review, #384).
  private let held: StripHeldSteps
  /// Keys whose write was refused when they arrived (#388): the whole store is read again when the app next comes to
  /// the front, or once a retried recovery succeeds, so a missed key needn't change again to land.
  private var missed: Set<String> = []
  /// Called after another device's months arrive, so the strip redraws.
  var onArrived: () -> Void = {}

  init?(database: AppDatabase, log: SessionLog) {
    guard let strip = database.dailyStrip, let settings = database.settings else { return nil }
    self.strip = strip
    held = StripHeldSteps(strip: strip, settings: settings)
    self.log = log
    self.database = database
    // Only an empty database can overwrite iCloud with less than it holds (a reinstall); one with rows is this
    // device's own record and publishes at once (Codex on #378). An empty one always waits: the key-value store syncs
    // even with iCloud Drive off, so no account check can say there is nothing to download (local review); with no
    // account at all, five quiet minutes online open it. A database already waiting stays waiting, even once its own
    // taps have given it rows (local review).
    let state = database.setting("strip_initial_sync")
    let empty = ((try? strip.ownRows()) ?? []).isEmpty
    gate = StripPublishGate(ready: state == "done" || (state != "waiting" && !empty))
    if !gate.ready {
      database.setSetting("strip_initial_sync", "waiting")
    } else if state != "done" && !empty {
      database.setSetting("strip_initial_sync", "done")
    }
    // The vendor id, not one kept in the database: a backup restored onto another phone gets a new one, so two
    // phones never write the same keys (Codex on #378). The database only reaches a new id by a restore or a
    // transfer, and the phone it came from may still be in use: what it carried was that phone's, so it becomes
    // that phone's peer rows (its keys update them, the newer change winning) instead of this one's, and nothing counts twice.
    device =
      UIDevice.current.identifierForVendor?.uuidString ?? database.setting("strip_device_id") ?? UUID().uuidString
    var handedOver = Set((database.setting("strip_handed_over") ?? "").split(separator: ",").map(String.init))
    if let old = database.setting("strip_device_id"), old != device {
      do {
        let moved = try strip.handOver(to: old)
        handedOver.insert(old)
        database.setSetting("strip_handed_over_at.\(old)", String(Int64(Date().timeIntervalSince1970 * 1000)))
        database.setSetting("strip_handed_over", handedOver.sorted().joined(separator: ","))
        // A wait and its held steps carried in the backup were the old phone's; a new id has nothing in iCloud to
        // overwrite, so this device publishes at once.
        gate.opened()
        database.setSetting("strip_initial_sync", "done")
        database.setSetting(StripHeldSteps.key, "{}")
        log.event("strip_sync", ["action": "device_changed", "handed_over_rows": moved])
      } catch {
        log.event("error", ["where": "strip_sync_hand_over", "message": "\(error)"])
        return nil
      }
    }
    // A database restored onto a device it once synced with holds that device's own rows as peer rows: they are
    // this device's, so they move back to its own table and count once (local review).
    do {
      let reclaimed = try strip.reclaim(from: device)
      if reclaimed > 0 { log.event("strip_sync", ["action": "reclaimed", "rows": reclaimed]) }
    } catch {
      log.event("error", ["where": "strip_sync_reclaim", "message": "\(error)"])
    }
    self.handedOver = handedOver
    database.setSetting("strip_device_id", device)
    NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
    ) { [weak self] note in
      let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
      let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
      MainActor.assumeIsolated { self?.arrived(keys: keys, reason: reason) }
    }
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.retryMissed(why: "foreground") }
    }
  }

  /// The keys a refused write skipped, and everything else the store holds, read again (#388).
  private func retryMissed(why: String) {
    guard !missed.isEmpty else { return }
    log.event("strip_sync", ["action": "retry_missed", "keys": missed.count, "why": why])
    missed = []  // a key that left the store is gone for good; one refused again comes back
    arrived(keys: Array(store.dictionaryRepresentation.keys), reason: nil)
  }

  /// At launch: every month this device has goes up (the first sync sends its history), the other devices' keys
  /// are read, and the store is asked to sync now.
  func start() {
    if ready {
      recoverThenPublish()
    } else {
      // Offline, waiting proves nothing, and publishing could overwrite the month in iCloud: only time online counts.
      log.event("strip_sync", ["action": "waiting_for_first_sync"])
      watchForAQuietCloud()
    }
    arrived(keys: Array(store.dictionaryRepresentation.keys), reason: nil)
    store.synchronize()
  }

  /// When no device has ever published, no download ever comes to end the wait (Codex on #378). Five minutes in a row
  /// online and in the foreground with none means iCloud has nothing of this device's to overwrite; after an arrival,
  /// a minute with nothing more (#388). Offline or suspended time never counts.
  private func watchForAQuietCloud() {
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] _ in
      Task { @MainActor in self?.restartQuiet() }
    }
    monitor.start(queue: .main)
    path = monitor
    for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification] {
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.restartQuiet() }
      }
    }
  }

  private var quietCounts: Bool {
    path?.currentPath.status == .satisfied && UIApplication.shared.applicationState != .background
  }

  /// The wait's deadline again, after the network, the app's state or an arrival changed.
  private func restartQuiet() {
    quiet?.cancel()
    guard !gate.ready else { return }
    wait.counting(quietCounts, at: .now)
    guard let deadline = wait.deadline else { return }
    quiet = Task { @MainActor [weak self] in
      // The continuous clock both ways: the wall clock set back can't leave the wait due but shut (#972).
      try? await Task.sleep(until: deadline, clock: .continuous)
      guard !Task.isCancelled, let self, self.quietCounts, self.wait.isDue(at: .now) else { return }
      self.open(why: self.wait.why)
    }
  }

  /// Something arrived while waiting: it may be only part of the download, so the quiet minute starts again (#388).
  private func settle(after why: String) {
    guard !ready else { return }
    wait.arrived(why, at: .now)
    restartQuiet()
  }

  /// The first sync has happened: this device's own months are merged back, then everything goes up.
  private func open(why: String) {
    guard !ready else { return }
    // A count stepped while waiting was built on nothing: the steps come off, the recovered count comes back, and
    // the steps land again on top of it. All of it or none: a failure rolls back, the steps stay held and the sync
    // stays closed, since publishing then could replace iCloud's months with a partial copy (Codex on #378). The
    // next arrival or launch tries again. The held steps clear in the same transaction, so none replays twice (#384).
    var steps: [StripHeldStep] = []
    let restored: Int
    do {
      steps = Array(try held.all().values)
      restored = try strip.inTransaction {
        var replayed: [(item: DailyItem, day: String, net: Int)] = []
        for s in steps {
          guard let item = DailyItem(rawValue: s.item) else { continue }
          let original = s.original.flatMap {
            $0.count == 2 ? StripRow(day: s.day, item: item, value: Int($0[0]), updatedAt: $0[1]) : nil
          }
          try strip.restoreOwn(item, day: s.day, to: original)
          replayed.append((item, s.day, s.net))
        }
        try recoverOwn()
        for s in replayed {
          try strip.set(s.item, day: s.day, value: try strip.ownValue(s.item, day: s.day) + s.net)
        }
        try held.clear()
        return replayed.count
      }
    } catch {
      log.event("error", ["where": "strip_sync_recover", "message": "\(error)", "why": why, "held_steps": steps.count])
      return
    }
    gate.opened()
    path?.cancel()
    path = nil
    quiet?.cancel()
    database.setSetting("strip_initial_sync", "done")
    log.event(
      "strip_sync",
      [
        "action": "first_sync", "why": why, "after": wait.after ?? "", "queued_months": pendingMonths.count,
        "replayed_steps": restored,
      ])
    pendingMonths = []
    publish(month: nil)
    onArrived()
  }

  /// This device's own months already in iCloud come back into its database first, so a reinstall (same vendor id,
  /// empty database) picks up where it was instead of overwriting them.
  /// A restore's rows the old phone never uploaded go up for it once it has been silent (`sendForSilent`, #379).
  /// Throws when the database refuses a row: the caller must not publish, or iCloud gets the partial copy.
  private func recoverOwn() throws {
    var count = 0
    for key in store.dictionaryRepresentation.keys {
      guard let parsed = StripSync.parse(key: key), parsed.device == device, let data = store.data(forKey: key)
      else { continue }
      let rows = StripSync.decode(data)
      try strip.mergeOwn(rows)
      count += rows.count
    }
    if count > 0 { log.event("strip_sync", ["action": "recovered_own", "rows": count]) }
  }

  /// A counter steps this device's own count, never below 0, and the new count comes back. While waiting for the
  /// first sync the step is held too, in the same transaction, so it lands on the count that sync brings back (#380)
  /// and a refused write leaves nothing to replay twice (#384).
  func step(_ item: DailyItem, day: String, by step: Int) throws -> Int {
    try held.step(item, day: day, by: step, holding: !gate.ready)
  }

  /// After a tap: that day's month goes up, or waits for the first sync, or for a recovery that failed to succeed.
  func changed(day: String) {
    switch gate.tap(day: day) {
    case .hold(let month): pendingMonths.insert(month)
    case .recoverFirst:
      recoverThenPublish()  // all months go up once it succeeds, this one included
      if gate.publishes { retryMissed(why: "recovered") }
    case .publish(let month): publish(month: month)
    }
  }

  /// This device's own iCloud months merged back, all or nothing, then everything goes up. A failure leaves no
  /// half-merged month and keeps publishing closed until a later try succeeds (Codex on #378).
  private func recoverThenPublish() {
    do {
      try strip.inTransaction { try recoverOwn() }
      gate.recovery(succeeded: true)
      publish(month: nil)
    } catch {
      gate.recovery(succeeded: false)
      log.event("error", ["where": "strip_sync_recover", "message": "\(error)", "publishing": "closed"])
    }
  }

  /// The oldest month iCloud carries now; older ones live only in each device's database (Codex on #378).
  private var oldestKept: String { StripSync.oldestKept(today: AccessoryLog.dateKey(Date())) }

  private func publish(month: String?) {
    do {
      let oldest = oldestKept
      let months = StripSync.encode(try strip.ownRows(month: month)).filter { $0.key >= oldest }
      // ponytail: stored unencrypted in iCloud KVS by design (Igor, 2026-10-18); encrypt before storing anything
      // sensitive here, or before App Store submission.
      // A later build's items in this month stay in iCloud, though this build can't read them (#388).
      for (m, data) in months {
        let key = StripSync.key(device: device, month: m)
        store.set(StripSync.carryingUnknown(data, from: store.data(forKey: key)), forKey: key)
      }
      // Every device's months that aged out leave the store, this one's and abandoned ids' alike (a replaced phone
      // never prunes its own), so it stays inside its quota; each device keeps its own copy (Codex on #378).
      let aged = store.dictionaryRepresentation.keys.filter {
        guard let parsed = StripSync.parse(key: $0) else { return false }
        return parsed.month < oldest
      }
      for key in aged { store.removeObject(forKey: key) }
      log.event(
        "strip_sync",
        ["action": "publish", "months": months.keys.sorted(), "all": month == nil, "aged_out": aged.count])
    } catch {
      log.event("error", ["where": "strip_sync_publish", "message": "\(error)"])
      return
    }
    if month == nil { sendForSilent() }
  }

  /// A restore's history was handed to the old phone's id; what that phone never sent shows here but not on the iPad.
  /// Once it has sent nothing for `StripSync.silentDays`, those rows go up under its keys, each month merged into the
  /// one iCloud holds, so nothing it sent is replaced and a revived old phone picks them up (#379).
  private func sendForSilent() {
    let now = Date()
    for old in handedOver.sorted() where old != device {
      do {
        // The hand-over counts as the old phone's last word: right after a restore iCloud may not have delivered its
        // keys yet, and an old backup's rows alone would look silent. An id handed over before #379 starts now.
        let stamp = "strip_handed_over_at.\(old)"
        guard let handed = database.setting(stamp).flatMap(Int64.init) else {
          database.setSetting(stamp, String(Int64(now.timeIntervalSince1970 * 1000)))
          continue
        }
        let rows = try strip.peerRows(old)
        guard StripSync.isSilent(newest: max(handed, rows.map(\.updatedAt).max() ?? 0), now: now) else { continue }
        let months = StripSync.unsentMonths(rows, oldest: oldestKept) {
          store.data(forKey: StripSync.key(device: old, month: $0))
        }
        guard !months.isEmpty else { continue }
        for (m, out) in months { store.set(out.data, forKey: StripSync.key(device: old, month: m)) }
        log.event(
          "strip_sync",
          [
            "action": "sent_for", "device": old, "months": months.keys.sorted(),
            "rows": months.values.reduce(0) { $0 + $1.rows },
          ])
      } catch {
        log.event("error", ["where": "strip_sync_send_for", "device": old, "message": "\(error)"])
      }
    }
  }

  private func arrived(keys: [String], reason: Int?) {
    switch reason {
    // The download is under way, not done (Apple delays writes during it): a quiet minute ends the wait (#388).
    case NSUbiquitousKeyValueStoreInitialSyncChange: settle(after: "initial_sync")
    case NSUbiquitousKeyValueStoreServerChange: settle(after: "server_change")
    case NSUbiquitousKeyValueStoreQuotaViolationChange:
      log.event("error", ["where": "strip_sync_quota", "message": "over the iCloud key-value store quota"])
    default: break
    }
    // Strip keys already in the store mean the download has begun, even if before this device listened.
    if !ready, store.dictionaryRepresentation.keys.contains(where: { StripSync.parse(key: $0) != nil }) {
      settle(after: "store_holds")
    }
    var keys = keys
    // Another iCloud account's data replaces this one's, and the changed keys may not be listed: start over from
    // everything the store now holds (Codex on #378).
    if reason == NSUbiquitousKeyValueStoreAccountChange {
      do {
        try strip.clearPeers(keeping: handedOver)
      } catch {
        gate.arrivalFailed()
        log.event(
          "error",
          ["where": "strip_sync_arrived", "message": "\(error)", "step": "clear_peers", "publishing": "closed"])
      }
      // The new account's own months for this device come back first, then this device's months go up over them.
      // Waiting, the first sync recovers them itself; ready, a failure keeps publishing closed until one succeeds.
      if ready { recoverThenPublish() }
      keys = Array(store.dictionaryRepresentation.keys)
      missed = []
      log.event("strip_sync", ["action": "account_change", "keys": keys.count])
      onArrived()
    }
    // Each key lands on its own (this device's own months back into its table where newer, the others' as peer
    // rows), so a refused one costs only itself and is read again later (#388).
    let arrival = strip.absorb(keys: keys, device: device, oldest: oldestKept) { store.data(forKey: $0) }
    for months in arrival.merged {
      for m in months.value { missed.remove(StripSync.key(device: months.key, month: m)) }
    }
    if !arrival.failed.isEmpty {
      missed.formUnion(arrival.failed.keys)
      gate.arrivalFailed()
      log.event(
        "error",
        [
          "where": "strip_sync_arrived", "message": arrival.failed.values.sorted().first ?? "",
          "keys": arrival.failed.keys.sorted(), "publishing": "closed",
        ])
    }
    let byDevice = arrival.merged
    guard !byDevice.isEmpty else { return }
    for (from, months) in byDevice {
      log.event(
        "strip_sync",
        ["action": "arrived", "device": from, "months": months, "reason": reason.map(String.init) ?? "launch"])
    }
    onArrived()
  }
}
