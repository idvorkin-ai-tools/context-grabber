//  Live context to Larry (#84, stories 099, 335, 337): events held until the Cockpit takes them, each once, oldest
//  first, with the time it happened; a refusal not retried; the route the Cockpit does not have yet is "waiting", not
//  "failed"; a day's wait drops it. Against a fake Cockpit speaking the shape proposed to Larry on 2026-11-20.

import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private let minute = 60_000.0
private let gym = KnownPlace(id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100)
private let pacific = TimeZone(identifier: "America/Los_Angeles") ?? .current
/// Monday 16 March 2026, 05:47:00 Pacific.
private let monday = 1_773_665_220_000.0

private func inside(_ t: Double) -> LocationPoint {
  LocationPoint(latitude: gym.latitude, longitude: gym.longitude, accuracy: 10, timestamp: monday + t * minute)
}

private func outside(_ t: Double) -> LocationPoint {
  LocationPoint(latitude: 47.6852, longitude: gym.longitude, accuracy: 10, timestamp: monday + t * minute)
}

/// A fake Cockpit: answers each request with the next status and body, and keeps what it was sent.
private final class FakeCockpit: @unchecked Sendable {
  var answers: [(Int, String)]
  var failWith: Error?
  private(set) var bodies: [[String: Any]] = []
  private(set) var requests: [URLRequest] = []

  init(_ answers: [(Int, String)]) { self.answers = answers }

  var transport: LiveContextSender.Transport {
    { [self] request in
      requests.append(request)
      if let body = request.httpBody, let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] {
        bodies.append(json)
      }
      if let failWith { throw failWith }
      let (status, body) = answers.isEmpty ? (200, #"{"ok": true}"#) : answers.removeFirst()
      let url = try XCTUnwrap(request.url)
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
      )
    }
  }
}

/// Started away from the gym, then an hour there and gone: an arrival and a departure waiting.
private func aGymVisit() -> LiveContext {
  var state = LiveContext()
  _ = state.observe([outside(-20), outside(-10)], places: [gym])
  _ = state.observe((0...60).map { inside(Double($0)) }, places: [gym])
  _ = state.observe([outside(61), outside(70)], places: [gym])
  return state
}

final class LiveContextSendTests: XCTestCase {
  private var lines: [[String: Any]] = []
  private func log(_ name: String, _ fields: [String: Any]) {
    XCTAssertEqual(name, "live_context")
    lines.append(fields)
  }

  func testAVisitIsSentOldestFirstWithItsOwnTimes() async throws {
    let state = aGymVisit()
    XCTAssertEqual(state.waiting.map(\.kind), [.arrived, .left])
    let cockpit = FakeCockpit([(200, #"{"ok": true, "id": "a"}"#), (200, #"{"ok": true, "id": "b"}"#)])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(state, now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)

    XCTAssertEqual(after.waiting, [])
    XCTAssertEqual(after.lastSent?.kind, .left)
    XCTAssertEqual(
      cockpit.requests.map { $0.url?.absoluteString },
      Array(repeating: "https://cockpit.example.ts.net/context", count: 2))
    XCTAssertEqual(cockpit.requests.first?.value(forHTTPHeaderField: "Origin"), "https://cockpit.example.ts.net")
    XCTAssertEqual(cockpit.requests.first?.httpMethod, "POST")
    let arrived = try XCTUnwrap(cockpit.bodies.first)
    XCTAssertEqual(arrived["type"] as? String, "arrived")
    XCTAssertEqual(arrived["place"] as? String, "Kettlebility")
    XCTAssertEqual(arrived["at"] as? String, "2026-03-16T05:47:00-07:00")
    XCTAssertEqual(arrived["sent_at"] as? String, "2026-03-16T07:07:00-07:00")
    XCTAssertEqual(arrived["id"] as? String, "arrived-13-1773665220000")
    XCTAssertNil(arrived["dwell_minutes"])
    let left = try XCTUnwrap(cockpit.bodies.last)
    XCTAssertEqual(left["type"] as? String, "left")
    XCTAssertEqual(left["at"] as? String, "2026-03-16T06:48:00-07:00")
    XCTAssertEqual(left["dwell_minutes"] as? Int, 61)
    // No position travels: only these keys.
    XCTAssertEqual(Set(left.keys), ["id", "type", "place", "at", "sent_at", "dwell_minutes"])
    XCTAssertEqual(lines.map { $0["action"] as? String }, ["sent", "sent"])
    XCTAssertEqual(lines.first?["place"] as? String, "Kettlebility")
  }

  func testUnreachableHoldsEverythingAndSendsItLaterWithTheSameIds() async {
    let state = aGymVisit()
    let away = FakeCockpit([])
    away.failWith = URLError(.cannotConnectToHost)
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: away.transport)
    let held = await sender.send(state, now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(held.waiting.count, 2)
    XCTAssertEqual(away.requests.count, 1, "stops at the first that cannot go")
    XCTAssertEqual(lines.last?["action"] as? String, "waiting")
    XCTAssertEqual(lines.last?["unreachable"] as? Bool, true)
    XCTAssertEqual(lines.last?["count"] as? Int, 2)

    let back = FakeCockpit([])
    let later = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: back.transport)
    let sent = await later.send(held, now: { Date(timeIntervalSince1970: (monday + 300 * minute) / 1000) }, log: log)
    XCTAssertEqual(sent.waiting, [])
    XCTAssertEqual(back.bodies.map { $0["id"] as? String }, state.waiting.map(\.id))
    XCTAssertEqual(back.bodies.first?["at"] as? String, "2026-03-16T05:47:00-07:00", "its own time, not the send's")
  }

  /// Story 338: the switch goes off while the first is on its way. Its request cancelled, the send stops and says so,
  /// with no stale "waiting" line counting what the switch dropped.
  func testASendCancelledBySwitchingOffSaysCancelledNotWaiting() async {
    let cockpit = FakeCockpit([])
    cockpit.failWith = URLError(.cancelled)
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(cockpit.requests.count, 1)
    XCTAssertEqual(after.waiting.count, 2)
    XCTAssertEqual(lines.map { $0["action"] as? String }, ["cancelled"])
    XCTAssertEqual(lines.first?["count"] as? Int, 2)
  }

  /// Story 338: switched off once the first has gone, the second never goes.
  func testNothingMoreGoesOnceTheSendIsCancelled() async {
    let cockpit = FakeCockpit([])
    let transport = cockpit.transport
    let sender = LiveContextSender(cockpit: "https://cockpit.example.ts.net", timeZone: pacific) { request in
      let answer = try await transport(request)
      withUnsafeCurrentTask { $0?.cancel() }
      return answer
    }
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(cockpit.requests.count, 1, "the second waits for the switch to come back on")
    XCTAssertEqual(after.waiting.map(\.kind), [.left])
    XCTAssertEqual(lines.map { $0["action"] as? String }, ["sent", "cancelled"])
    XCTAssertEqual(lines.last?["count"] as? Int, 1)
  }

  func testTheRouteNotThereYetWaitsRatherThanFails() async {
    let cockpit = FakeCockpit([(404, #"{"ok": false, "error": "not found"}"#)])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(after.waiting.count, 2)
    XCTAssertEqual(lines.last?["action"] as? String, "waiting")
    XCTAssertEqual(lines.last?["reason"] as? String, "\(LiveContextWire.notYet) (HTTP 404)")
  }

  func testARefusalIsNotRetriedAndTheNextGoesOn() async {
    let cockpit = FakeCockpit([(400, #"{"ok": false, "reason": "bad at"}"#), (200, #"{"ok": true}"#)])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(after.waiting, [])
    XCTAssertEqual(lines.map { $0["action"] as? String }, ["failed", "sent"])
    XCTAssertEqual(lines.first?["reason"] as? String, "bad at")
    XCTAssertEqual(lines.first?["status"] as? Int, 400)
  }

  func testAServerErrorWaits() async {
    let cockpit = FakeCockpit([(503, #"{"ok": false, "error": "restarting"}"#)])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(after.waiting.count, 2)
    XCTAssertEqual(lines.last?["reason"] as? String, "restarting")
  }

  func testADuplicateCountsAsSent() async {
    let cockpit = FakeCockpit([(200, #"{"ok": true, "duplicate": true}"#), (200, #"{"ok": true}"#)])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(after.waiting, [])
    XCTAssertEqual(lines.first?["duplicate"] as? Bool, true)
  }

  func testOverADayWaitingIsDropped() async {
    let cockpit = FakeCockpit([])
    let sender = LiveContextSender(
      cockpit: "https://cockpit.example.ts.net", timeZone: pacific, transport: cockpit.transport)
    // The arrival (05:47) is over a day old at 06:00 the next day; the departure (06:48) is not.
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + (24 * 60 + 13) * minute) / 1000) }, log: log)
    XCTAssertEqual(lines.map { $0["action"] as? String }, ["dropped", "sent"])
    XCTAssertEqual(lines.first?["kind"] as? String, "arrived")
    XCTAssertEqual(cockpit.bodies.map { $0["type"] as? String }, ["left"])
    XCTAssertEqual(after.waiting, [])
  }

  func testNoAddressSendsNothingAndSaysWhy() async {
    let cockpit = FakeCockpit([])
    let sender = LiveContextSender(cockpit: ChatCockpit.nowhere, timeZone: pacific, transport: cockpit.transport)
    let after = await sender.send(
      aGymVisit(), now: { Date(timeIntervalSince1970: (monday + 80 * minute) / 1000) }, log: log)
    XCTAssertEqual(after.waiting.count, 2)
    XCTAssertEqual(cockpit.requests.count, 0)
    XCTAssertEqual(lines.first?["action"] as? String, "waiting")
  }

  func testAnEventIsHeldOnceAndTheStateKeeps() throws {
    var state = aGymVisit()
    _ = state.advance(to: monday + 200 * minute, recording: true)
    XCTAssertEqual(state.waiting.count, 2)
    let kept = try JSONDecoder().decode(LiveContext.self, from: JSONEncoder().encode(state))
    XCTAssertEqual(kept, state)
  }

  /// context-grabber-1zrt: Background Tracking turned off two minutes into the gym, the app opened an hour later.
  /// The silence is the phone no longer listening, so nothing settles; what had settled before still goes.
  func testWithRecordingOffTheQuietSettlesNothing() {
    var state = LiveContext()
    _ = state.observe([outside(-20), outside(-10)], places: [gym])
    _ = state.observe([inside(0), inside(2)], places: [gym])
    XCTAssertEqual(state.advance(to: monday + 60 * minute, recording: false), [])
    XCTAssertTrue(state.waiting.isEmpty)

    var visit = aGymVisit()
    _ = visit.observe([inside(80), inside(82)], places: [gym])  // back at the gym, then tracking off
    XCTAssertEqual(visit.advance(to: monday + 200 * minute, recording: false), [])
    XCTAssertEqual(visit.waiting.map(\.kind), [.arrived, .left])

    XCTAssertEqual(visit.advance(to: monday + 200 * minute, recording: true).count, 1)  // recording on, it would
  }

  func testTheDetectedLineNamesThePlaceAndTimes() {
    let event = LiveContextEvent(
      kind: .arrived, placeId: 13, place: "Kettlebility", at: monday, detectedAt: monday + 5 * minute)
    let fields = LiveContext.logFields(.event(event), ignoredFixes: 2, timeZone: pacific)
    XCTAssertEqual(fields["action"] as? String, "detected")
    XCTAssertEqual(fields["kind"] as? String, "arrived")
    XCTAssertEqual(fields["at"] as? String, "2026-03-16T05:47:00-07:00")
    XCTAssertEqual(fields["detected_at"] as? String, "2026-03-16T05:52:00-07:00")
    XCTAssertEqual(fields["ignored_fixes"] as? Int, 2)
    let start = LiveContext.logFields(.started(place: nil, at: monday), ignoredFixes: 0, timeZone: pacific)
    XCTAssertEqual(start["action"] as? String, "started")
    XCTAssertNil(start["ignored_fixes"])
  }
}
