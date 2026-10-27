//  Story 304: the archive's line in Settings (spec 2026-10-19-native-stats-archive-design.md, "In Settings"). The
//  archive runs silently; this says whether it is caught up, and which stream is not and why, so a Cockpit out of
//  reach or a refused page is seen before it becomes a gap in Larry's week.

import Foundation

/// What the last archive run ended with, kept for Settings (a `settings` row, JSON).
public struct ArchiveOutcome: Equatable, Sendable, Codable {
  /// When the run started, UTC milliseconds.
  public var at: Int64
  /// Each stream that did not catch up, and why: `retry`, `refused`, `read`, `pages`, `cancelled`.
  public var stopped: [String: String]
  /// The HTTP status of each refused stream.
  public var refused: [String: Int]

  public init(at: Int64, stopped: [String: String] = [:], refused: [String: Int] = [:]) {
    self.at = at
    self.stopped = stopped
    self.refused = refused
  }

  public var caughtUp: Bool { stopped.isEmpty }

  /// Every stream caught up, sent another stretch of its history (`pages`, a restarted stream's re-read too) or
  /// was cut short by iOS: the archive moved, nothing is wrong. A first backfill is runs of these.
  public var madeProgress: Bool { stopped.values.allSatisfy { $0 == "pages" || $0 == "cancelled" } }

  public var json: String {
    (try? JSONEncoder().encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
  }

  public init?(json: String?) {
    guard let json, let value = try? JSONDecoder().decode(Self.self, from: Data(json.utf8)) else { return nil }
    self = value
  }
}

public enum ArchiveStatus {
  public struct Line: Equatable, Sendable {
    public var text: String
    /// Worth Igor's attention: shown in red.
    public var trouble: Bool
  }

  /// No progress for longer than this is trouble.
  public static let staleMs: Int64 = 24 * 60 * 60 * 1000

  /// The headline first, then one line per stream that did not catch up. `lastCaughtUp`: when a run last ended
  /// with every stream caught up. `lastProgress`: when a run last made progress (`ArchiveOutcome.madeProgress`).
  /// `firstRun`: when the first run started, the clock for a phone that has never got anywhere. The headline is red
  /// only when more than a day has passed since the newest of these that applies.
  public static func lines(
    sends: Bool, outcome: ArchiveOutcome?, lastCaughtUp: Int64?, lastProgress: Int64? = nil, firstRun: Int64? = nil,
    now: Int64
  ) -> [Line] {
    guard sends else { return [Line(text: "Not sent: this build has no archive address", trouble: false)] }
    guard let outcome else { return [Line(text: "Not run yet", trouble: false)] }
    let moved = [lastCaughtUp, lastProgress, outcome.madeProgress ? outcome.at : nil].compactMap { $0 }.max()
    let stale = now - (moved ?? firstRun ?? outcome.at) > staleMs
    var out: [Line] = []
    if outcome.caughtUp {
      out.append(Line(text: "Caught up \u{00B7} \(ago(outcome.at, now: now))", trouble: now - outcome.at > staleMs))
      return out
    }
    let since = lastCaughtUp.map { "last caught up \(ago($0, now: now))" } ?? "never caught up"
    let headline =
      outcome.stopped.values.contains("retry")
      ? "Cockpit out of reach \u{00B7} tried \(ago(outcome.at, now: now))"
      : "Behind \u{00B7} last run \(ago(outcome.at, now: now))"
    out.append(Line(text: "\(headline) \u{00B7} \(since)", trouble: stale))
    for stream in outcome.stopped.keys.sorted() {
      let why = outcome.stopped[stream] ?? ""
      let text = "\(name(stream)): \(reason(why, status: outcome.refused[stream]))"
      out.append(Line(text: text, trouble: why == "refused"))
    }
    return out
  }

  /// `location.points` → "Trail", `health.HKQuantityTypeIdentifierHeartRate` → "Heart Rate", `strip.balloons` →
  /// "Strip: balloons".
  public static func name(_ stream: String) -> String {
    if stream == ArchiveStream.points { return "Trail" }
    if stream.hasPrefix("strip.") { return "Strip: " + String(stream.dropFirst("strip.".count)) }
    if stream.hasPrefix("health.") {
      var id = String(stream.dropFirst("health.".count))
      for prefix in ["HKQuantityTypeIdentifier", "HKCategoryTypeIdentifier", "HKWorkoutTypeIdentifier", "HK"]
      where id.hasPrefix(prefix) {
        id = String(id.dropFirst(prefix.count))
        break
      }
      // "HeartRateVariabilitySDNN" → "Heart Rate Variability SDNN": a space where a capital follows a small letter.
      var words = ""
      var previous: Character?
      for c in id {
        if c.isUppercase, previous?.isLowercase == true { words += " " }
        words.append(c)
        previous = c
      }
      return words.isEmpty ? "Workouts" : words
    }
    return stream
  }

  static func reason(_ why: String, status: Int?) -> String {
    switch why {
    case "retry": return "waiting for the Cockpit"
    case "refused": return "refused\(status.map { " (\($0))" } ?? ""); the rest waits on the phone"
    case "read": return "could not be read on the phone"
    case "pages": return "still sending its history"
    case "cancelled": return "cut short by iOS"
    default: return why
    }
  }

  /// "just now", "12 min ago", "3 h ago", "2 days ago".
  public static func ago(_ ms: Int64, now: Int64) -> String {
    let minutes = max(0, (now - ms) / 60_000)
    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes) min ago" }
    let hours = minutes / 60
    if hours < 48 { return "\(hours) h ago" }
    return "\(hours / 24) days ago"
  }
}
