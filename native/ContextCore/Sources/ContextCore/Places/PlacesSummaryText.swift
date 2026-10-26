//  Story 022: the Larry export's `places`, as text a coach can read: a per-week rollup of hours per place and the
//  last three days as named stays with local times. No coordinates. Port of the React Native app's
//  buildSummaryWeekly / buildSummaryRecent (lib/clustering_v2.ts), with one fix: a week is labelled by how many
//  weeks before the current one it is, not by its rank, so a week with no stays never moves a label.

import Foundation

public enum PlacesSummaryText {
  /// The recent section's days, counted back from `now`.
  public static let recentDays = 3
  /// A shorter transit is not worth a line.
  public static let minTransitMs = 60 * 60 * 1000.0

  /// Where the export's trail starts: local midnight of the Sunday a week before this week's, so the weekly line
  /// has this week and last whole.
  public static func since(now: Double, calendar: Calendar = .current) -> Double {
    guard let thisWeek = weekStart(now, calendar), let last = calendar.date(byAdding: .day, value: -7, to: thisWeek)
    else { return now - 14 * 24 * 60 * 60 * 1000 }
    return Geo.ms(last)
  }

  /// The export's section, or nil when there is nothing to say (no stays), as the React Native app left it.
  public static func summary(_ clusters: StayClusters, now: Double, calendar: Calendar = .current) -> PlacesSummary? {
    let weekly = weekly(clusters.stays, now: now, calendar: calendar)
    let recent = recent(clusters.stays, transit: clusters.transit, now: now, calendar: calendar)
    if weekly.isEmpty && recent.isEmpty { return nil }
    return PlacesSummary(weekly: weekly, recent: recent)
  }

  /// "This week: Home 92h, Office 28h\nLast week: Home 101h": one line per week with a stay (Sunday to Saturday,
  /// by when the stay began), newest first, places by hours, most first.
  public static func weekly(_ stays: [Stay], now: Double, calendar: Calendar = .current) -> String {
    guard !stays.isEmpty, let thisWeek = weekStart(now, calendar) else { return "" }
    var weeks: [Int: [String: Int]] = [:]
    var order: [Int: [String]] = [:]
    for stay in stays {
      // Local midnights, a whole number of calendar days apart whatever daylight saving did between them.
      guard let start = weekStart(stay.startTime, calendar),
        let days = calendar.dateComponents([.day], from: start, to: thisWeek).day
      else { continue }
      let ago = days / 7
      if weeks[ago]?[stay.placeId] == nil { order[ago, default: []].append(stay.placeId) }
      weeks[ago, default: [:]][stay.placeId, default: 0] += stay.durationMinutes
    }
    return weeks.keys.sorted().map { ago in
      let label = ago == 0 ? "This week" : ago == 1 ? "Last week" : ago < 0 ? "Later" : "\(ago) weeks ago"
      let minutes = weeks[ago] ?? [:]
      // Most hours first; a tie keeps the order the places first appeared in.
      let places = (order[ago] ?? []).enumerated().sorted {
        (minutes[$0.element] ?? 0, -$0.offset) > (minutes[$1.element] ?? 0, -$1.offset)
      }
      let parts = places.map { "\($0.element) \(PlacesDaily.jsNumber(hours(minutes[$0.element] ?? 0)))h" }
      return "\(label): " + parts.joined(separator: ", ")
    }.joined(separator: "\n")
  }

  /// "Mon Mar 15: Home Mon Mar 15 10pm–Tue Mar 16 7am (9h), [1.2h/14.3km], Office Tue Mar 16 9am–5pm (8h)": the
  /// stays that ended in the last three days, a line per day they began on, with transits of an hour or more.
  public static func recent(_ stays: [Stay], transit: [TransitSegment], now: Double, calendar: Calendar = .current)
    -> String
  {
    let cutoff = now - Double(recentDays) * 24 * 60 * 60 * 1000
    var headers: [String] = []
    var events: [String: [(time: Double, text: String)]] = [:]
    for stay in stays.sorted(by: { $0.startTime < $1.startTime }) where stay.endTime >= cutoff {
      let header = date(stay.startTime, calendar)
      if events[header] == nil {
        headers.append(header)
        events[header] = []
      }
      guard stay.durationMinutes > 0 else { continue }
      let range = timeRange(stay.startTime, stay.endTime, calendar)
      events[header]?.append((stay.startTime, "\(stay.placeId) \(range) (\(duration(stay.durationMinutes)))"))
    }
    for t in transit where t.endTime >= cutoff && Double(t.durationMinutes) * 60 * 1000 >= minTransitMs {
      let header = date(t.startTime, calendar)
      guard events[header] != nil else { continue }
      events[header]?.append(
        (t.startTime, "[\(duration(t.durationMinutes))/\(PlacesDaily.jsNumber(t.distanceKm))km]"))
    }
    return headers.compactMap { header in
      let parts = (events[header] ?? []).enumerated().sorted {
        ($0.element.time, $0.offset) < ($1.element.time, $1.offset)
      }.map(\.element.text)
      return parts.isEmpty ? nil : "\(header): " + parts.joined(separator: ", ")
    }.joined(separator: "\n")
  }

  // MARK: - formatting, as the React Native app's

  private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// One decimal, as Math.round(minutes / 6) / 10.
  static func hours(_ minutes: Int) -> Double { jsRound(Double(minutes) / 6) / 10 }

  /// "45min", "1.5h".
  static func duration(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes)min" : "\(PlacesDaily.jsNumber(hours(minutes)))h"
  }

  /// "Fri Mar 29".
  static func date(_ ms: Double, _ calendar: Calendar) -> String {
    let c = calendar.dateComponents([.weekday, .month, .day], from: Geo.date(ms))
    return "\(weekdays[(c.weekday ?? 1) - 1]) \(months[(c.month ?? 1) - 1]) \(c.day ?? 0)"
  }

  /// "10pm", "10:58am".
  static func time(_ ms: Double, _ calendar: Calendar) -> String {
    let c = calendar.dateComponents([.hour, .minute], from: Geo.date(ms))
    let h = c.hour ?? 0
    let m = c.minute ?? 0
    let period = h >= 12 ? "pm" : "am"
    let h12 = h % 12 == 0 ? 12 : h % 12
    return m == 0 ? "\(h12)\(period)" : "\(h12):\(String(format: "%02d", m))\(period)"
  }

  /// "Fri Mar 29 10:58am–11:11am", or with the end's date when it is another day.
  static func timeRange(_ start: Double, _ end: Double, _ calendar: Calendar) -> String {
    let sameDay = calendar.isDate(Geo.date(start), inSameDayAs: Geo.date(end))
    let tail = sameDay ? time(end, calendar) : "\(date(end, calendar)) \(time(end, calendar))"
    return "\(date(start, calendar)) \(time(start, calendar))\u{2013}\(tail)"
  }

  /// Local midnight of the Sunday that starts the week `ms` is in.
  private static func weekStart(_ ms: Double, _ calendar: Calendar) -> Date? {
    let day = calendar.startOfDay(for: Geo.date(ms))
    let back = calendar.component(.weekday, from: day) - 1
    return calendar.date(byAdding: .day, value: -back, to: day)
  }
}
