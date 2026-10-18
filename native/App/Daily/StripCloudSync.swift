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
  /// Called after another device's months arrive, so the strip redraws.
  var onArrived: () -> Void = {}

  init?(database: AppDatabase, log: SessionLog) {
    guard let strip = database.dailyStrip else { return nil }
    self.strip = strip
    self.log = log
    // The vendor id, not one kept in the database: a backup restored onto another phone gets a new one, so two
    // phones never write the same keys (Codex on #378). The database only reaches a new id by a restore or a
    // transfer, and the phone it came from may still be in use: what it carried was that phone's, so it becomes
    // that phone's peer rows (replaced by its keys when they arrive) instead of this one's, and nothing counts twice.
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
    publish(month: nil)
    arrived(keys: Array(store.dictionaryRepresentation.keys), reason: nil)
    store.synchronize()
  }

  /// After a tap: that day's month goes up.
  func changed(day: String) { publish(month: StripSync.month(of: day)) }

  /// The oldest month iCloud carries now; older ones live only in each device's database (Codex on #378).
  private var oldestKept: String { StripSync.oldestKept(today: AccessoryLog.dateKey(Date())) }

  private func publish(month: String?) {
    do {
      let oldest = oldestKept
      let months = StripSync.encode(try strip.ownRows(month: month)).filter { $0.key >= oldest }
      for (m, data) in months { store.set(data, forKey: StripSync.key(device: device, month: m)) }
      // This device's months that aged out leave the store, so it stays inside its quota.
      let aged = store.dictionaryRepresentation.keys.filter {
        guard let parsed = StripSync.parse(key: $0) else { return false }
        return parsed.device == device && parsed.month < oldest
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
        publish(month: nil)
        keys = Array(store.dictionaryRepresentation.keys)
        log.event("strip_sync", ["action": "account_change", "keys": keys.count])
        onArrived()
      }
      for key in keys {
        guard let (from, month) = StripSync.parse(key: key), from != device else { continue }
        // A month older than iCloud carries is kept as this device last had it: its key leaving is pruning.
        guard month >= oldestKept else { continue }
        let rows = (store.data(forKey: key)).map(StripSync.decode) ?? []
        try strip.replacePeer(from, month: month, rows: rows)
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
