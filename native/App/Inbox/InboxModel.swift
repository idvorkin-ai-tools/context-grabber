//  #305, stories 038 and 039: the Inbox the share extension fills, read from the App Group, and its items sent to
//  Larry's inbox on the Cockpit each time the app opens or comes to the front (plan 2026-10-18-share-inbox-plan.md).

import ContextCore
import CoreGraphics
import Foundation

@MainActor
final class InboxModel: ObservableObject {
  @Published private(set) var items: [InboxItem] = []
  @Published private(set) var sending = false
  /// Each image item's small preview, decoded once per item.
  private(set) var thumbnails: [String: CGImage] = [:]
  var waitingCount: Int { items.filter { $0.status == .waiting }.count }

  let store: InboxStore?
  private let log: SessionLog
  private let database: AppDatabase
  private let cockpit: String

  init(log: SessionLog, database: AppDatabase, cockpit: String = CockpitPage.url) {
    self.log = log
    self.database = database
    self.cockpit = cockpit
    store = InboxStore.shared()
  }

  /// Reads the Inbox, logs what the share extension added since the last look, then sends what waits.
  func refresh(reason: String) {
    reload()
    announceNew()
    send(reason: reason)
  }

  func reload() {
    guard let store else { return }
    let read = store.items()
    var kept: [String: CGImage] = [:]
    for item in read.items where item.kind == .image {
      kept[item.id] =
        thumbnails[item.id] ?? store.image(of: item).flatMap { InboxSend.thumbnail($0, maxPixels: 168) }
    }
    thumbnails = kept
    items = read.items
    for name in read.unreadable { log.event("error", ["where": "inbox_read", "file": name]) }
  }

  func delete(_ item: InboxItem) {
    do {
      try store?.delete(item)
      log.event(
        "inbox", ["action": "deleted", "item": item.id, "kind": item.kind.rawValue, "status": "\(item.status)"])
    } catch {
      log.event("error", ["where": "inbox_delete", "item": item.id, "message": "\(error)"])
    }
    reload()
  }

  /// One `inbox` added line per item, the first time the app sees it: the kind and the size, never the content.
  private func announceNew() {
    let seen = Set((database.setting("inbox_seen") ?? "").split(separator: ",").map(String.init))
    let fresh = items.filter { !seen.contains($0.id) }
    for item in fresh.reversed() {
      var fields: [String: Any] = ["action": "added", "item": item.id, "kind": item.kind.rawValue]
      fields["note"] = item.note != nil
      if let text = item.text { fields["text_chars"] = text.count }
      if let bytes = store?.imageBytes(of: item) { fields["bytes"] = bytes }
      if let site = item.site { fields["site"] = site }
      log.event("inbox", fields)
    }
    // Only ids still in the Inbox, so the setting does not grow forever.
    database.setSetting("inbox_seen", items.map(\.id).joined(separator: ","))
  }

  private func send(reason: String) {
    guard let store, !sending, waitingCount > 0 else { return }
    sending = true
    let sender = InboxSender(store: store, cockpit: cockpit) { try await URLSession.shared.data(for: $0) }
    Task { [log] in
      _ = await sender.sendWaiting { type, fields in
        var fields = fields
        fields["why"] = reason
        log.event(type, fields)
      }
      sending = false
      reload()
    }
  }

  // MARK: Launch hooks (docs/TESTING.md)

  /// `GRABBER_INBOX_FIXTURE=1`: three items as the share extension would write them, for the simulator. Their ids
  /// mark them as fixtures, which are never sent: the simulator reaches the tailnet too.
  func addFixture() {
    guard let store else { return log.event("error", ["where": "inbox_fixture", "message": "no App Group"]) }
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    do {
      try store.add(
        InboxItem(
          id: InboxItem.fixtureID(), kind: .link, sharedAt: now - 2_000, url: "https://idvork.in/eulogy",
          note: "for Larry"))
      try store.add(
        InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: now - 1_000, text: "A thought worth talking about.")
      )
      try store.add(InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: now, text: "Another one."))
    } catch {
      log.event("error", ["where": "inbox_fixture", "message": "\(error)"])
    }
  }
}
