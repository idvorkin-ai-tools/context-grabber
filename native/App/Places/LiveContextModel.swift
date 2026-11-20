//  Live context to Larry (#84, stories 099, 335–337; spec 2026-10-17-native-live-context-design.md): every batch of
//  trail points goes through the arrival/departure detector, what settles waits in the database's settings, and the
//  sender tries the Cockpit each time a position wakes the app and each time it comes to the front. The detector's
//  state lives across launches, so a background wake carries on where the last one stopped.

import ContextCore
import Foundation
import UIKit

@MainActor
final class LiveContextModel: ObservableObject {
  static let stateKey = "live_context"
  /// The switch, on unless turned off (story 338).
  static let onKey = "live_context_on"

  /// The last event the Cockpit took, for Settings.
  @Published private(set) var lastSent: LiveContextEvent?
  @Published private(set) var waitingCount = 0
  /// *Tell Larry when I arrive and leave*.
  @Published private(set) var on: Bool

  private let log: SessionLog
  private let database: AppDatabase
  private let sender: LiveContextSender
  private var state: LiveContext
  private var sending = false
  private var placesError: String?

  init(log: SessionLog, database: AppDatabase, cockpit: String) {
    self.log = log
    self.database = database
    sender = LiveContextSender(cockpit: cockpit, transport: { try await URLSession.shared.data(for: $0) })
    state = LiveContext()
    on = database.setting(Self.onKey) != "0"
    if let raw = database.setting(Self.stateKey) {
      do {
        state = try JSONDecoder().decode(LiveContext.self, from: Data(raw.utf8))
      } catch {
        // Unreadable: start again from wherever the phone settles next, and say so.
        log.event("error", ["where": "live_context_state", "message": "\(error)"])
      }
    }
    published()
  }

  /// New points from the trail, as the tracker stored them.
  func observe(_ points: [LocationPoint]) {
    guard on else { return }
    let places: [KnownPlace]
    do {
      places = try database.locations?.knownPlaces() ?? []
    } catch {
      let message = "\(error)"
      if message != placesError {
        placesError = message
        log.event("error", ["where": "live_context_places", "message": message])
      }
      return
    }
    placesError = nil
    settled(state.observe(points, places: places))
    send(reason: "position")
  }

  /// The switch. Off drops what waits (nothing is sent with it off); on starts afresh, so where the phone already is
  /// is the unsent starting point.
  func setOn(_ value: Bool, from source: String) {
    guard value != on else { return }
    on = value
    database.setSetting(Self.onKey, value ? "1" : "0")
    log.event(
      "live_context", ["action": "switch", "on": value, "from": source, "dropped": value ? 0 : state.waiting.count])
    if value {
      state.detector = LiveContextDetector()
    } else {
      state.waiting = []
    }
    save()
  }

  /// Recording was turned on again: where the phone was when it stopped says nothing about now, so the next place it
  /// settles in is a fresh, unsent starting point. What still waits to be sent keeps waiting.
  func restart(reason: String) {
    state.detector = LiveContextDetector()
    log.event("live_context", ["action": "restart", "reason": reason])
    save()
  }

  /// The app came to the front: the quiet since the last position counts as staying, then what waits goes.
  func foreground() {
    guard on else { return }
    settled(state.advance(to: Geo.ms(Date())))
    send(reason: "foreground")
  }

  private func settled(_ changes: [LiveContextDetector.Change]) {
    for change in changes {
      log.event("live_context", LiveContext.logFields(change, ignoredFixes: state.detector.takeIgnoredFixes()))
    }
    save()
  }

  private func send(reason: String) {
    guard on, !sending, !state.waiting.isEmpty else { return }
    sending = true
    // A position's wake gives the app seconds; the request asks for a little more.
    let task = UIApplication.shared.beginBackgroundTask(withName: "live_context")
    let start = state
    let log = self.log
    Task {
      let after = await sender.send(start) { name, fields in
        var fields = fields
        fields["trigger"] = reason
        log.event(name, fields)
      }
      // Only the sending moves: what settled meanwhile stays waiting.
      let gone = Set(start.waiting.map(\.id)).subtracting(after.waiting.map(\.id))
      state.waiting.removeAll { gone.contains($0.id) }
      if let sent = after.lastSent, sent != start.lastSent {
        state.lastSent = sent
        state.lastSentAt = after.lastSentAt
      }
      save()
      sending = false
      if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
    }
  }

  private func save() {
    published()
    do {
      let raw = try JSONEncoder().encode(state)
      database.setSetting(Self.stateKey, String(decoding: raw, as: UTF8.self))
    } catch {
      log.event("error", ["where": "live_context_save", "message": "\(error)"])
    }
  }

  private func published() {
    lastSent = state.lastSent
    waitingCount = state.waiting.count
  }
}
