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
  /// The ids this install wrote under before, whose keys are removed whenever they show up: on a restored phone
  /// they arrive with iCloud's first sync, after launch.
  private let retired: Set<String>
  private let log: SessionLog
  /// Called after another device's months arrive, so the strip redraws.
  var onArrived: () -> Void = {}

  init?(database: AppDatabase, log: SessionLog) {
    guard let strip = database.dailyStrip else { return nil }
    self.strip = strip
    self.log = log
    // The vendor id, not one kept in the database: a backup restored onto a new phone gets a new one, so two
    // phones never write the same keys (Codex on #378). When it changes, the keys this install wrote under the old
    // one are removed, or their counts would add up twice.
    // ponytail: a restore onto a second phone while the first stays in use doubles that shared history's counts
    // once; the upgrade is a per-install id in the Keychain (ThisDeviceOnly) with the old keys handed over.
    device =
      UIDevice.current.identifierForVendor?.uuidString ?? database.setting("strip_device_id") ?? UUID().uuidString
    var retired = Set((database.setting("strip_retired_devices") ?? "").split(separator: " ").map(String.init))
    if let old = database.setting("strip_device_id"), old != device {
      retired.insert(old)
      database.setSetting("strip_retired_devices", retired.sorted().joined(separator: " "))
      log.event("strip_sync", ["action": "device_changed", "retired": retired.count])
    }
    retired.remove(device)
    self.retired = retired
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
    publish(month: nil)
    arrived(keys: Array(store.dictionaryRepresentation.keys), reason: nil)
    store.synchronize()
  }

  /// After a tap: that day's month goes up.
  func changed(day: String) { publish(month: StripSync.month(of: day)) }

  private func publish(month: String?) {
    do {
      let months = StripSync.encode(try strip.ownRows(month: month))
      for (m, data) in months { store.set(data, forKey: StripSync.key(device: device, month: m)) }
      log.event("strip_sync", ["action": "publish", "months": months.keys.sorted(), "all": month == nil])
    } catch {
      log.event("error", ["where": "strip_sync_publish", "message": "\(error)"])
    }
  }

  private func arrived(keys: [String], reason: Int?) {
    switch reason {
    case NSUbiquitousKeyValueStoreQuotaViolationChange:
      log.event("error", ["where": "strip_sync_quota", "message": "over the iCloud key-value store quota"])
    default: break
    }
    var keys = keys
    var byDevice: [String: [String]] = [:]
    var removed = 0
    do {
      // Another iCloud account's data replaces this one's, and the changed keys may not be listed: start over from
      // everything the store now holds (Codex on #378).
      if reason == NSUbiquitousKeyValueStoreAccountChange {
        try strip.clearPeers()
        publish(month: nil)
        keys = Array(store.dictionaryRepresentation.keys)
        log.event("strip_sync", ["action": "account_change", "keys": keys.count])
        onArrived()
      }
      for key in keys {
        guard let (from, month) = StripSync.parse(key: key), from != device else { continue }
        if retired.contains(from) {
          store.removeObject(forKey: key)
          removed += 1
          continue
        }
        let rows = (store.data(forKey: key)).map(StripSync.decode) ?? []
        try strip.replacePeer(from, month: month, rows: rows)
        byDevice[from, default: []].append(month)
      }
    } catch {
      log.event("error", ["where": "strip_sync_arrived", "message": "\(error)"])
    }
    if removed > 0 { log.event("strip_sync", ["action": "removed_retired", "keys": removed]) }
    guard !byDevice.isEmpty else { return }
    for (from, months) in byDevice {
      log.event(
        "strip_sync",
        ["action": "arrived", "device": from, "months": months.sorted(), "reason": reason.map(String.init) ?? "launch"])
    }
    onArrived()
  }
}
