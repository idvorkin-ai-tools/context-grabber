//  Live context to Larry (#84, stories 099, 335, 337): the arrivals and departures the detector settles, held until
//  the Cockpit takes them, each sent once with its own id, oldest first. The wire is the shape proposed to Larry on
//  2026-11-20 (cockpit#63 item 1, modelled on POST /inbox): `POST /context` with the Cockpit's own Origin, a body of
//  `{id, type, place, at, sent_at, dwell_minutes?}`, answered `200 {ok, id, received_at, duplicate?}`, a 4xx with a
//  `reason` (not retried) or a 5xx (retried). Until the Cockpit has the route its 404 is "not yet", so events wait
//  (and drop after a day) rather than fail. No position ever goes, only the place's name.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The detector's state and the events still to send, kept as one value between the app's wakes.
public struct LiveContext: Equatable, Sendable, Codable {
  /// An event still waiting after this long is dropped: Larry hearing on Thursday about Monday's gym is noise.
  public static let maxWaitMs = 24 * 60 * 60 * 1000.0

  public var detector = LiveContextDetector()
  /// Oldest first.
  public var waiting: [LiveContextEvent] = []
  /// The last event the Cockpit took, and when (UTC unix ms): Settings shows it.
  public var lastSent: LiveContextEvent?
  public var lastSentAt: Double?

  public init() {}

  /// Positions from the trail, in time order: what settles is held to send.
  public mutating func observe(_ points: [LocationPoint], places: [KnownPlace]) -> [LiveContextDetector.Change] {
    var changes: [LiveContextDetector.Change] = []
    for point in points { changes += detector.observe(point, places: places) }
    hold(changes)
    return changes
  }

  /// No new position by `now` (the app came to the front, or a timer): silence counts as staying.
  public mutating func advance(to now: Double) -> [LiveContextDetector.Change] {
    let changes = detector.advance(to: now)
    hold(changes)
    return changes
  }

  private mutating func hold(_ changes: [LiveContextDetector.Change]) {
    for case .event(let event) in changes where !waiting.contains(where: { $0.id == event.id }) {
      waiting.append(event)
    }
  }

  /// Takes out what has waited over a day, for the log.
  public mutating func dropStale(now: Double) -> [LiveContextEvent] {
    let stale = waiting.filter { now - $0.at > Self.maxWaitMs }
    waiting.removeAll { now - $0.at > Self.maxWaitMs }
    return stale
  }

  mutating func taken(_ event: LiveContextEvent, at now: Double) {
    waiting.removeAll { $0.id == event.id }
    lastSent = event
    lastSentAt = now
  }

  mutating func refused(_ event: LiveContextEvent) {
    waiting.removeAll { $0.id == event.id }
  }

  /// The `live_context` line for a change the detector made (`detected`, or `started` for the unsent starting point).
  public static func logFields(_ change: LiveContextDetector.Change, ignoredFixes: Int, timeZone: TimeZone = .current)
    -> [String: Any]
  {
    var fields: [String: Any]
    switch change {
    case .started(let place, let at):
      fields = ["action": "started", "place": place ?? "", "at": LiveContextWire.iso(at, timeZone)]
    case .event(let event):
      fields = event.logFields(timeZone)
      fields["action"] = "detected"
      fields["detected_at"] = LiveContextWire.iso(event.detectedAt, timeZone)
    }
    if ignoredFixes > 0 { fields["ignored_fixes"] = ignoredFixes }
    return fields
  }
}

extension LiveContextEvent {
  func logFields(_ timeZone: TimeZone) -> [String: Any] {
    var fields: [String: Any] = [
      "id": id, "kind": kind.rawValue, "place": place, "at": LiveContextWire.iso(at, timeZone),
    ]
    if let dwellMinutes { fields["dwell_minutes"] = dwellMinutes }
    return fields
  }
}

public enum LiveContextWire {
  public enum Outcome: Equatable, Sendable {
    case sent(duplicate: Bool)
    /// The request itself is wrong: not retried.
    case refused(status: Int, reason: String)
    case retry(reason: String)
  }

  /// When it happened, with Igor's own offset (`2026-03-16T05:47:54-07:00`): the time he lived it.
  public static func iso(_ ms: Double, _ timeZone: TimeZone) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    f.timeZone = timeZone
    return f.string(from: Date(timeIntervalSince1970: ms / 1000))
  }

  public static func body(_ event: LiveContextEvent, sentAt: Double, timeZone: TimeZone) -> [String: Any] {
    var body: [String: Any] = [
      "id": event.id, "type": event.kind.rawValue, "place": event.place, "at": iso(event.at, timeZone),
      "sent_at": iso(sentAt, timeZone),
    ]
    if let dwell = event.dwellMinutes { body["dwell_minutes"] = dwell }
    return body
  }

  public static func request(_ event: LiveContextEvent, cockpit: String, sentAt: Double, timeZone: TimeZone) throws
    -> URLRequest
  {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("context"))
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(
      withJSONObject: body(event, sentAt: sentAt, timeZone: timeZone), options: [.sortedKeys])
    return request
  }

  /// The route the Cockpit does not have yet answers 404 (or 405): that is "not yet", so the event waits.
  public static let notYet = "The Cockpit does not take arrivals yet"

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .retry(reason: error ?? "no answer") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if (200..<300).contains(status), json?["ok"] as? Bool == true {
      return .sent(duplicate: json?["duplicate"] as? Bool == true)
    }
    if status == 404 || status == 405 { return .retry(reason: "\(notYet) (HTTP \(status))") }
    let reason = (json?["reason"] as? String) ?? (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }
}

/// Sends what waits, oldest first, and logs each answer as a `live_context` line. Stops at the first retry: the
/// Cockpit is unreachable or not ready, so the rest would wait the same way.
public struct LiveContextSender: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  let cockpit: String
  let timeZone: TimeZone
  let transport: Transport

  public init(cockpit: String, timeZone: TimeZone = .current, transport: @escaping Transport) {
    self.cockpit = cockpit
    self.timeZone = timeZone
    self.transport = transport
  }

  public func send(_ start: LiveContext, now: @Sendable () -> Date = Date.init, log: (String, [String: Any]) -> Void)
    async -> LiveContext
  {
    var state = start
    for event in state.dropStale(now: Geo.ms(now())) {
      var fields = event.logFields(timeZone)
      fields["action"] = "dropped"
      fields["reason"] = "waited over a day"
      log("live_context", fields)
    }
    guard !state.waiting.isEmpty else { return state }
    guard cockpit != ChatCockpit.nowhere else {
      log("live_context", ["action": "waiting", "count": state.waiting.count, "reason": ChatCockpit.noAddress])
      return state
    }
    for event in state.waiting {
      // Story 338: the switch went off mid-send. Nothing more goes, and what was dropped isn't called waiting.
      guard !Task.isCancelled else { return cancelled(state, log) }
      let sentAt = Geo.ms(now())
      var fields = event.logFields(timeZone)
      let outcome: LiveContextWire.Outcome
      do {
        let request = try LiveContextWire.request(event, cockpit: cockpit, sentAt: sentAt, timeZone: timeZone)
        let (data, response) = try await transport(request)
        outcome = LiveContextWire.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
      } catch {
        if Task.isCancelled || Self.isCancellation(error) { return cancelled(state, log) }
        if CockpitReach.isAway(error) { fields["unreachable"] = true }
        outcome = LiveContextWire.outcome(status: nil, body: nil, error: error.localizedDescription)
      }
      switch outcome {
      case .sent(let duplicate):
        state.taken(event, at: sentAt)
        fields["action"] = "sent"
        if duplicate { fields["duplicate"] = true }
        fields["late_s"] = Int(((sentAt - event.detectedAt) / 1000).rounded())
        log("live_context", fields)
      case .refused(let status, let reason):
        state.refused(event)
        fields["action"] = "failed"
        fields["status"] = status
        fields["reason"] = reason
        log("live_context", fields)
      case .retry(let reason):
        fields["action"] = "waiting"
        fields["reason"] = reason
        fields["count"] = state.waiting.count
        log("live_context", fields)
        return state
      }
    }
    return state
  }

  private func cancelled(_ state: LiveContext, _ log: (String, [String: Any]) -> Void) -> LiveContext {
    log("live_context", ["action": "cancelled", "count": state.waiting.count])
    return state
  }

  static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}

/// The line under *Tell Larry when I arrive and leave* (story 338): the last thing sent, or why nothing is.
public enum LiveContextStatus {
  public static func line(
    on: Bool, recording: Bool, knownPlaces: Int, lastSent: LiveContextEvent?, waiting: Int,
    timeZone: TimeZone = .current
  ) -> String {
    guard on else { return "Off: Larry hears nothing about where you go." }
    var parts: [String] = []
    if !recording {
      parts.append("Background tracking is off, so nothing new is noticed")
    } else if knownPlaces == 0 {
      return "Nothing is sent until a place is named."
    } else if let lastSent {
      let verb = lastSent.kind == .arrived ? "Arrived at" : "Left"
      parts.append("\(verb) \(lastSent.place) · \(clock(lastSent.at, timeZone))")
    } else {
      parts.append("Nothing sent yet")
    }
    if waiting > 0 { parts.append("\(waiting) waiting for the Cockpit") }
    return parts.joined(separator: " · ")
  }

  static func clock(_ ms: Double, _ timeZone: TimeZone) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "EEE h:mm"
    return f.string(from: Date(timeIntervalSince1970: ms / 1000))
  }
}
