//  Arrivals at and departures from known places, as they happen, for Larry (#84, stories 099 and 335–336;
//  spec 2026-10-17-native-live-context-design.md). Pure: positions in, events out; the app keeps the state between
//  wakes and sends what comes out.
//
//  An arrival counts once the phone has been inside a known place for five minutes, a departure once it has been
//  outside it for five minutes. The phone stops reporting while it lies still, so silence counts as staying where
//  the last position was: `advance(to:)` lets the five minutes run out without a new position. A position the phone
//  reports as less precise than 100 m is ignored (on the real trail one 1.4 km fix at home would have been a
//  departure). The first place the phone settles in after a fresh start is taken as the starting point, unsent.

import Foundation

public struct LiveContextEvent: Equatable, Sendable, Codable {
  public enum Kind: String, Sendable, Codable {
    case arrived
    case left
  }

  /// Stable for the event, so a resend counts once: `<kind>-<place id>-<when, unix ms>`.
  public var id: String
  public var kind: Kind
  public var placeId: Int64
  /// The place's name when the phone arrived there.
  public var place: String
  /// When it happened, UTC unix ms: the first position inside (arrived) or outside (left).
  public var at: Double
  /// When the five minutes ran out, UTC unix ms.
  public var detectedAt: Double
  /// On a departure, the minutes since the arrival, when the arrival was seen.
  public var dwellMinutes: Int?

  public init(kind: Kind, placeId: Int64, place: String, at: Double, detectedAt: Double, dwellMinutes: Int? = nil) {
    id = "\(kind.rawValue)-\(placeId)-\(Int64(at.rounded(.down)))"
    self.kind = kind
    self.placeId = placeId
    self.place = place
    self.at = at
    self.detectedAt = detectedAt
    self.dwellMinutes = dwellMinutes
  }
}

public struct LiveContextDetector: Equatable, Sendable, Codable {
  public static let settleMs = 5 * 60 * 1000.0
  /// Positions whose reported accuracy is worse than this many metres are ignored.
  public static let maxAccuracyMeters = 100.0

  public enum Change: Equatable, Sendable {
    /// The starting point after a fresh start: a known place's name, or nil for none. Nothing is sent for it.
    case started(place: String?, at: Double)
    case event(LiveContextEvent)
  }

  struct Where: Equatable, Sendable, Codable {
    var placeId: Int64
    var name: String
    /// When the arrival happened; nil when this place is the starting point.
    var since: Double?
  }

  struct Candidate: Equatable, Sendable, Codable {
    /// nil: inside no known place.
    var placeId: Int64?
    var name: String?
    var since: Double
  }

  /// False until the starting point is taken.
  var started = false
  /// The known place the phone is at; nil for none.
  var current: Where?
  /// When the phone was first seen outside `current`, while that has not yet lasted five minutes.
  var outsideSince: Double?
  /// Somewhere other than `current` the phone has been since `since`, not yet for five minutes.
  var candidate: Candidate?
  var lastSeen: Double?
  /// Imprecise positions ignored since the app last took the count, for the log.
  public private(set) var ignoredFixes = 0

  public init() {}

  /// The known place the phone is at, once started.
  public var currentPlace: String? { current?.name }

  /// Clears the count of ignored positions, once the app has logged it.
  public mutating func takeIgnoredFixes() -> Int {
    defer { ignoredFixes = 0 }
    return ignoredFixes
  }

  /// Takes one position from the trail, in time order (an older one than the last is ignored).
  public mutating func observe(_ point: LocationPoint, places: [KnownPlace]) -> [Change] {
    if let accuracy = point.accuracy, accuracy > Self.maxAccuracyMeters {
      ignoredFixes += 1
      return []
    }
    let t = point.timestamp
    if let lastSeen, t < lastSeen { return [] }
    let changes = advance(to: t)
    lastSeen = t
    let hit = KnownPlaces.match(latitude: point.latitude, longitude: point.longitude, in: places).map {
      places[$0.index]
    }
    if started, hit?.id == current?.placeId {
      outsideSince = nil
      candidate = nil
      return changes
    }
    if started, current != nil, outsideSince == nil { outsideSince = t }
    if candidate == nil || candidate?.placeId != hit?.id {
      candidate = Candidate(placeId: hit?.id, name: hit?.name, since: t)
    }
    return changes
  }

  /// Lets time pass with no new position: what has lasted five minutes by `now` settles.
  public mutating func advance(to now: Double) -> [Change] {
    var changes: [Change] = []
    if started, let here = current, let out = outsideSince, now - out >= Self.settleMs {
      let dwell = here.since.map { Int(((out - $0) / 60000).rounded()) }
      changes.append(
        .event(
          LiveContextEvent(
            kind: .left, placeId: here.placeId, place: here.name, at: out, detectedAt: out + Self.settleMs,
            dwellMinutes: dwell)))
      current = nil
      outsideSince = nil
    }
    guard let next = candidate, now - next.since >= Self.settleMs else { return changes }
    if !started {
      started = true
      current = next.placeId.map { Where(placeId: $0, name: next.name ?? "", since: nil) }
      candidate = nil
      outsideSince = nil
      changes.append(.started(place: next.name, at: next.since + Self.settleMs))
    } else if current == nil, let id = next.placeId {
      let name = next.name ?? ""
      current = Where(placeId: id, name: name, since: next.since)
      candidate = nil
      changes.append(
        .event(
          LiveContextEvent(
            kind: .arrived, placeId: id, place: name, at: next.since, detectedAt: next.since + Self.settleMs)))
    } else if current == nil {
      candidate = nil
    }
    return changes
  }
}
