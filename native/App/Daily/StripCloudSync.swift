//  #376, story 153: the daily strip on every device signed into Igor's iCloud, through the iCloud key-value store
//  (plan 2026-10-17-strip-sync-plan.md). This device writes only its own monthly keys; the other devices' keys are
//  read into `daily_strip_peers`, and the strip shows the merge. Without iCloud the store holds values locally and
//  nothing arrives, so the strip works as before on this device alone.

import ContextCore
import Foundation
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
  /// #380: false until this database has seen iCloud's first sync. Until then nothing is published (a reinstall's
  /// empty months would overwrite the ones in iCloud); the store's initial-sync or server change opens it.
  private var ready: Bool
  private var pendingMonths: Set<String> = []
  /// Counter steps made before the first sync, by day and item: the row as it was before them and their sum.
  private var waitingSteps: [String: (item: DailyItem, day: String, original: StripRow?, net: Int)] = [:]
  /// Called after another device's months arrive, so the strip redraws.
  var onArrived: () -> Void = {}

  init?(database: AppDatabase, log: SessionLog) {
    guard let strip = database.dailyStrip else { return nil }
    self.strip = strip
    self.log = log
    self.database = database
    // Only an empty database can overwrite iCloud with less than it holds (a reinstall); one with rows is this
    // device's own record, and with no iCloud account nothing leaves the phone. Those publish at once (Codex on #378).
    let empty = ((try? strip.ownRows()) ?? []).isEmpty
    ready =
      database.setting("strip_initial_sync") == "done" || !empty || FileManager.default.ubiquityIdentityToken == nil
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
        database.setSetting("strip_handed_over", handedOver.sorted().joined(separator: ","))
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
  }

  /// At launch: every month this device has goes up (the first sync sends its history), the other devices' keys
  /// are read, and the store is asked to sync now.
  func start() {
    recoverOwn()
    if ready {
      publish(month: nil)
    } else {
      // No timeout: offline, a minute proves nothing, and publishing then could overwrite the month in iCloud.
      // ponytail: if iCloud never reports a first sync for an empty database, its taps stay on this device until a
      // launch where it does (#380); the upgrade is a check of what the store holds once the network is back.
      log.event("strip_sync", ["action": "waiting_for_first_sync"])
    }
    arrived(keys: Array(store.dictionaryRepresentation.keys), reason: nil)
    store.synchronize()
  }

  /// The first sync has happened: this device's own months are merged back, then everything goes up.
  private func open(why: String) {
    guard !ready else { return }
    ready = true
    database.setSetting("strip_initial_sync", "done")
    // A count stepped while waiting was built on nothing: the steps come off, the recovered count comes back, and
    // the steps land again on top of it.
    let steps = Array(waitingSteps.values)
    waitingSteps = [:]
    var restored: [(item: DailyItem, day: String, original: StripRow?, net: Int)] = []
    do {
      for s in steps {
        try strip.restoreOwn(s.item, day: s.day, to: s.original)
        restored.append(s)
      }
    } catch {
      log.event("error", ["where": "strip_sync_replay", "message": "\(error)"])
    }
    recoverOwn()
    do {
      for s in restored {
        try strip.set(s.item, day: s.day, value: try strip.ownValue(s.item, day: s.day) + s.net)
      }
    } catch {
      log.event("error", ["where": "strip_sync_replay", "message": "\(error)"])
    }
    log.event(
      "strip_sync",
      [
        "action": "first_sync", "why": why, "queued_months": pendingMonths.count, "replayed_steps": restored.count,
      ])
    pendingMonths = []
    publish(month: nil)
    onArrived()
  }

  /// This device's own months already in iCloud come back into its database first, so a reinstall (same vendor id,
  /// empty database) picks up where it was instead of overwriting them.
  /// ponytail: a restore's rows that the old phone never uploaded stay on this phone if that phone is retired (#379);
  /// the upgrade is publishing handed-over rows under the old id once it has been silent for a while.
  private func recoverOwn() {
    do {
      var count = 0
      for key in store.dictionaryRepresentation.keys {
        guard let parsed = StripSync.parse(key: key), parsed.device == device, let data = store.data(forKey: key)
        else { continue }
        let rows = StripSync.decode(data)
        try strip.mergeOwn(rows)
        count += rows.count
      }
      if count > 0 { log.event("strip_sync", ["action": "recovered_own", "rows": count]) }
    } catch {
      log.event("error", ["where": "strip_sync_recover", "message": "\(error)"])
    }
  }

  /// Before a counter steps: while waiting for the first sync, the step is remembered so it lands on the count that
  /// sync brings back (#380).
  func stepping(_ item: DailyItem, day: String, by step: Int) {
    guard !ready else { return }
    let key = "\(day)/\(item.rawValue)"
    if waitingSteps[key] == nil {
      do {
        let original = try strip.ownRows(month: StripSync.month(of: day)).first { $0.day == day && $0.item == item }
        waitingSteps[key] = (item, day, original, 0)
      } catch {
        log.event("error", ["where": "strip_sync_replay", "message": "\(error)"])
        return
      }
    }
    waitingSteps[key]?.net += step
  }

  /// After a tap: that day's month goes up, or waits for the first sync.
  func changed(day: String) {
    guard ready else {
      pendingMonths.insert(StripSync.month(of: day))
      return
    }
    publish(month: StripSync.month(of: day))
  }

  /// The oldest month iCloud carries now; older ones live only in each device's database (Codex on #378).
  private var oldestKept: String { StripSync.oldestKept(today: AccessoryLog.dateKey(Date())) }

  private func publish(month: String?) {
    do {
      let oldest = oldestKept
      let months = StripSync.encode(try strip.ownRows(month: month)).filter { $0.key >= oldest }
      for (m, data) in months { store.set(data, forKey: StripSync.key(device: device, month: m)) }
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
    }
  }

  private func arrived(keys: [String], reason: Int?) {
    switch reason {
    case NSUbiquitousKeyValueStoreInitialSyncChange:
      open(why: "initial_sync")  // the store now holds the download: own months merge back, then all goes up
    case NSUbiquitousKeyValueStoreServerChange:
      open(why: "server_change")  // the server answered, so the download has come
    case NSUbiquitousKeyValueStoreQuotaViolationChange:
      log.event("error", ["where": "strip_sync_quota", "message": "over the iCloud key-value store quota"])
    default: break
    }
    var keys = keys
    var byDevice: [String: [String]] = [:]
    do {
      // Another iCloud account's data replaces this one's, and the changed keys may not be listed: start over from
      // everything the store now holds (Codex on #378).
      if reason == NSUbiquitousKeyValueStoreAccountChange {
        try strip.clearPeers(keeping: handedOver)
        if ready { publish(month: nil) }
        keys = Array(store.dictionaryRepresentation.keys)
        log.event("strip_sync", ["action": "account_change", "keys": keys.count])
        onArrived()
      }
      for key in keys {
        guard let (from, month) = StripSync.parse(key: key) else { continue }
        // A month older than iCloud carries, or a key that left (only its owner pruning removes one), is kept as this
        // device last had it.
        guard month >= oldestKept, let data = store.data(forKey: key) else { continue }
        if from == device {
          // This device's own months, downloaded after a reinstall: back into its table where newer (local review).
          try strip.mergeOwn(StripSync.decode(data))
        } else {
          try strip.mergePeer(from, month: month, rows: StripSync.decode(data))
        }
        byDevice[from, default: []].append(month)
      }
    } catch {
      log.event("error", ["where": "strip_sync_arrived", "message": "\(error)"])
    }
    guard !byDevice.isEmpty else { return }
    for (from, months) in byDevice {
      log.event(
        "strip_sync",
        ["action": "arrived", "device": from, "months": months.sorted(), "reason": reason.map(String.init) ?? "launch"])
    }
    onArrived()
  }
}
