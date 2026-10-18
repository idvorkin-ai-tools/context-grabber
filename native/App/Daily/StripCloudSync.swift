//  #376, story 153: the daily strip on every device signed into Igor's iCloud, through the iCloud key-value store
//  (plan 2026-10-17-strip-sync-plan.md). This device writes only its own monthly keys; the other devices' keys are
//  read into `daily_strip_peers`, and the strip shows the merge. Without iCloud the store holds values locally and
//  nothing arrives, so the strip works as before on this device alone.

import ContextCore
import Foundation

@MainActor
final class StripCloudSync {
  private let store = NSUbiquitousKeyValueStore.default
  private let strip: DailyStrip
  private let device: String
  private let log: SessionLog
  /// Called after another device's months arrive, so the strip redraws.
  var onArrived: () -> Void = {}

  init?(database: AppDatabase, log: SessionLog) {
    guard let strip = database.dailyStrip else { return nil }
    self.strip = strip
    self.log = log
    if let id = database.setting("strip_device_id") {
      device = id
    } else {
      device = UUID().uuidString
      database.setSetting("strip_device_id", device)
    }
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
    case NSUbiquitousKeyValueStoreAccountChange:
      log.event("strip_sync", ["action": "account_change"])
    default: break
    }
    var byDevice: [String: [String]] = [:]
    do {
      for key in keys {
        guard let (from, month) = StripSync.parse(key: key), from != device else { continue }
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
