# Context Grabber — Swift Port Specification

## Overview

Single-screen iOS app that reads HealthKit data, captures GPS, maintains a background location trail in SQLite, and exports structured JSON for AI life-coaching. Currently Expo/React Native/TypeScript — porting to native SwiftUI + Swift.

## Swift Tech Stack

| Current (RN/Expo) | Swift Equivalent |
|-------------------|-----------------|
| React Native | SwiftUI |
| expo-sqlite | SwiftData or GRDB.swift |
| @kingstinct/react-native-healthkit | HealthKit framework (native) |
| expo-location | CoreLocation (CLLocationManager) |
| expo-task-manager | CLLocationManager background updates |
| expo-file-system | FileManager |
| expo-sharing | UIActivityViewController |
| expo-updates (OTA) | TestFlight / App Store (no OTA equivalent) |
| Jest | XCTest / Swift Testing |

---

## 1. SQLite Schema

Six tables, all created at app init with `CREATE TABLE IF NOT EXISTS`.

### `locations`
```sql
id          INTEGER PRIMARY KEY AUTOINCREMENT
latitude    REAL NOT NULL
longitude   REAL NOT NULL
accuracy    REAL            -- nullable, meters
timestamp   INTEGER NOT NULL -- UTC unix milliseconds
```
Index: `idx_locations_timestamp ON locations(timestamp)`

### `settings`
```sql
key   TEXT PRIMARY KEY
value TEXT NOT NULL
```
Defaults: `schema_version=1`, `tracking_enabled=false`, `retention_days=30`

### `known_places`
```sql
id             INTEGER PRIMARY KEY AUTOINCREMENT
name           TEXT NOT NULL
latitude       REAL NOT NULL
longitude      REAL NOT NULL
radius_meters  REAL NOT NULL DEFAULT 100
```

### `health_raw_cache`
```sql
metric     TEXT NOT NULL   -- MetricKey string
date_key   TEXT NOT NULL   -- "YYYY-MM-DD"
data       TEXT NOT NULL   -- JSON array of raw samples
cached_at  INTEGER NOT NULL -- UTC unix ms
PRIMARY KEY (metric, date_key)
```

### `health_computed_cache`
```sql
metric     TEXT NOT NULL
date_key   TEXT NOT NULL
data       TEXT NOT NULL   -- JSON of aggregated daily value
cached_at  INTEGER NOT NULL
PRIMARY KEY (metric, date_key)
```

### `health_cache_meta`
```sql
key   TEXT PRIMARY KEY
value TEXT NOT NULL
```
Row: `cache_version=2` — bumping this purges both cache tables on next launch.

---

## 2. Health Data Collection

### HealthKit Authorization

Request read access to all 10 quantity/category types on every grab. HealthKit is idempotent — redundant requests are safe.

### Metrics Queried

| Metric | HK Identifier | Query Type | Time Window | Aggregation |
|--------|--------------|------------|-------------|-------------|
| steps | `HKQuantityTypeIdentifierStepCount` | `statisticsQuery cumulativeSum` | today midnight→now | sum |
| heartRate | `HKQuantityTypeIdentifierHeartRate` | `mostRecentSample` | any time | latest |
| activeEnergy | `HKQuantityTypeIdentifierActiveEnergyBurned` | `statisticsQuery cumulativeSum` | today midnight→now | sum |
| walkingDistance | `HKQuantityTypeIdentifierDistanceWalkingRunning` | `statisticsQuery cumulativeSum` | today midnight→now | sum |
| sleep | `HKCategoryTypeIdentifierSleepAnalysis` | `categorySamples` | yesterday noon→today noon | interval merge |
| weight | `HKQuantityTypeIdentifierBodyMass` | `mostRecentSample` (unit: kg) | any time | latest |
| meditation | `HKCategoryTypeIdentifierMindfulSession` | `categorySamples` | today midnight→now | sum durations |
| hrv | `HKQuantityTypeIdentifierHeartRateVariabilitySDNN` | `mostRecentSample` | any time | latest |
| restingHeartRate | `HKQuantityTypeIdentifierRestingHeartRate` | `mostRecentSample` | any time | latest |
| exerciseMinutes | `HKQuantityTypeIdentifierAppleExerciseTime` | `quantitySamples` | today midnight→now | sum quantities |

All queries wrapped in `Promise.allSettled` equivalent — individual failures return nil, never crash the grab.

### Sleep Processing (Critical Algorithm)

HealthKit sleep value encoding:
- 0 = InBed (excluded from sleep total)
- 1 = Asleep (counted)
- 2 = Awake (excluded)
- 3 = Core (counted)
- 4 = Deep (counted)
- 5 = REM (counted)

**Sleep window: noon-to-noon (not midnight-to-midnight).** Query yesterday noon to today noon. This captures overnight sessions correctly.

**Interval merge required.** Apple Watch and iPhone can both report the same sleep period. Filter to actual sleep stages (1, 3, 4, 5), then merge overlapping intervals before summing. Do NOT simply sum `(endDate - startDate)`.

**Per-source breakdown:** Group samples by `HKSourceRevision.source.name`. For each source, compute: bedtime, wakeTime, coreHours, deepHours, remHours, awakeHours.

### Output Shape: `HealthData`
```swift
struct HealthData {
    let steps: Int?
    let heartRate: Int?                    // bpm, rounded
    let sleepHours: Double?                // 1 decimal
    let bedtime: String?                   // ISO 8601 UTC
    let wakeTime: String?                  // ISO 8601 UTC
    let sleepBySource: [String: SourceSleepSummary]?
    let activeEnergy: Int?                 // kcal, rounded
    let walkingDistance: Double?            // km, 2 decimal
    let weight: Double?                    // kg, 2 decimal
    let weightDaysLast7: Int?              // distinct days with readings
    let meditationMinutes: Double?         // 1 decimal
    let hrv: Double?                       // ms, 1 decimal
    let restingHeartRate: Int?             // rounded
    let exerciseMinutes: Int?              // rounded
}
```

---

## 3. Location Tracking

### Foreground GPS
Single `CLLocationManager.requestLocation()` with default accuracy. Returns `(latitude, longitude, timestamp)` or nil.

### Background Tracking
**Opt-in** (defaults to OFF). Uses `CLLocationManager` with:
- `allowsBackgroundLocationUpdates = true`
- `activityType = .other`
- `desiredAccuracy = kCLLocationAccuracyHundredMeters` (balanced)
- `showsBackgroundLocationIndicator = true`

**Required Info.plist keys:**
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `UIBackgroundModes: ["location"]`

**Storage:** Each background location event → INSERT into `locations` table. No deduplication.

### Pruning
`DELETE FROM locations WHERE timestamp < (now - retentionDays * 86400000)`

Triggered on:
1. App init (after DB ready)
2. App enters foreground
3. User changes retention_days (debounced 1 second)

---

## 4. Location Clustering (v2 Algorithm)

Temporal stay-detection. No downsampling. O(n log n) sort + O(n) single pass.

### Parameters
```
STAY_RADIUS        = 100m
MIN_STAY_DURATION  = 5 minutes
MAX_POINT_GAP      = 4 hours
MERGE_GAP          = 30 minutes
MIN_TRANSIT_SUMMARY = 1 hour
RECENT_DAYS        = 3
```

### Pipeline
1. Sort points by timestamp
2. Label points against known places (O(n*k))
3. **Detect stays:** Walk points in time order with anchor. Extend stay if within STAY_RADIUS. Long gap (>4h) only ends stay if ALSO moved > STAY_RADIUS. Known place label change forces boundary.
4. **Merge stays:** Consecutive stays at same location within MERGE_GAP → merge
5. **Assign places:** Known place → name; unknown → "Place N" with discovered-place list and centroid proximity matching
6. **Transit annotation:** Gaps between stays get duration + distance
7. **Format summaries:** `summaryRecent` (last 3 days, grouped by day) + `summaryWeekly` (weekly rollup)

### Key Logic: Stay Detection
```
For each point p (in time order):
  gap = p.timestamp - lastPointTime
  dist = haversine(anchor, p)

  if knownPlaceLabel changed:
    finalize current stay, start new at p
  else if gap > 4h AND dist > 100m:
    finalize current stay, start new at p
  else if gap > 4h AND dist <= 100m:
    extend stay (covers overnight at home)
  else if dist <= 100m:
    extend stay, update centroid incrementally
  else:
    finalize current stay, start new at p

Finalize: only emit stay if duration >= 5 minutes
```

### Output Types
```swift
struct Stay {
    let placeId: String       // "Home", "Office", "Place 1"
    let centroid: CLLocationCoordinate2D
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let pointCount: Int
}

struct TransitSegment {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let distanceKm: Double
    let fromPlaceId: String
    let toPlaceId: String
}
```

### v1-Compatible Export Shape
The JSON export uses v1 format for backward compatibility:
```swift
struct LocationSummary {
    let clusters: [PlaceCluster]  // aggregated by placeId
    let timeline: [PlaceVisit]    // ordered stays as visits
    let summary: String           // flat timeline text, visits >= 0.5h
}
```

---

## 5. Weekly Aggregation & Caching

### Metric Keys
`steps`, `heartRate`, `sleep`, `activeEnergy`, `walkingDistance`, `weight`, `meditation`, `hrv`, `restingHeartRate`, `exerciseMinutes`

### Display Config Per Metric
```swift
struct MetricConfig {
    let label: String
    let unit: String
    let color: Color      // hex
    let chartType: ChartType  // .bar or .line
    let sublabel: String
}
```
Line chart metrics: heartRate, weight, hrv, restingHeartRate. All others: bar chart.

### Cache Strategy
- **Today:** always re-fetched from HealthKit (never cached)
- **Past days:** cached permanently in SQLite after first fetch
- **Cache version:** bumping the `cache_version` constant purges all cached data
- Build 7 date keys using **local time** (not UTC) — "your Tuesday" means local Tuesday

### Per-Metric Fetch Logic

| Metric | HealthKit Query | Aggregation |
|--------|----------------|-------------|
| steps, activeEnergy, walkingDistance | `statisticsQuery cumulativeSum` per day | sum |
| exerciseMinutes | `quantitySamples` per day | sum quantities |
| heartRate, hrv, restingHeartRate | `quantitySamples` per day | → HeartRateDaily (min/max/avg/q1/median/q3) |
| sleep | `categorySamples` (12h before day start → day end) | interval merge → hours |
| weight | `quantitySamples` (unit: kg) per day | latest per day |
| meditation | `categorySamples` per day | sum durations |

### HeartRateDaily
```swift
struct HeartRateDaily {
    let date: String       // "YYYY-MM-DD"
    let avg: Double?
    let min: Double?
    let max: Double?
    let q1: Double?
    let median: Double?
    let q3: Double?
    let count: Int
    let raw: [(value: Double, time: String)]
}
```
Percentiles use R-7 linear interpolation method.

---

## 6. Statistics (Box Plots)

```swift
struct BoxPlotStats {
    let min, p5, p25, p50, p75, p95, max: Double  // all 1 decimal
    let values: [Double]  // sorted input
}
```
Uses R-7 linear interpolation percentile method. Returns nil if no finite values.

---

## 7. Data Export

### Summary Share (7-day)
```swift
struct SummaryExport: Codable {
    let days: [DailyExportEntry]          // 7 entries
    let weeklyStats: WeeklyStatsExport    // per-metric percentile stats
    let locationSummary: LocationSummary? // clusters + timeline + summary text
}

struct DailyExportEntry: Codable {
    let date: String                      // "YYYY-MM-DD"
    let dayOfWeek: String                 // "Monday", etc.
    let steps: Int?
    let heartRate: HeartRateExport?       // { avg, min, max }
    let sleepHours: Double?
    let activeEnergy: Int?
    let walkingDistanceKm: Double?
    let weightKg: Double?
    let meditationMinutes: Double?
    let hrvMs: Double?
    let restingHeartRate: Int?
    let exerciseMinutes: Int?
}

struct WeeklyStatsExport: Codable {
    // Per metric: { min, p5, p25, p50, p75, p95, max } or null
}
```

JSON.stringify with 2-space indent → iOS share sheet.

### Raw Share
```swift
struct RawExport: Codable {
    let timestamp: String          // ISO 8601
    let health: HealthData
    let location: LocationCoord?
    let locationClusters: LocationSummary?
}
```

### Database Export
Copy SQLite file to cache directory → `UIActivityViewController` with MIME type `application/x-sqlite3`, UTI `public.database`.

---

## 8. UI Screens

### Main Screen
- **Header:** Title "Context Grabber", subtitle, 3 icon buttons (refresh, settings, about)
- **Auto-grab on launch** after DB is ready
- **Summary banner:** One-liner: "8,241 steps | Slept 7.2hrs (11pm–6:15am) | 73 bpm | ..."
- **Metric grid:** 2-column, 10 tappable cards. Each shows label, value, and BoxPlot (if stats loaded) or sublabel
- **Location card:** Full width, tappable → opens Location detail sheet
- **Timestamp:** Right-aligned below location card
- **Bottom bar:** "Summary" and "Raw" share buttons (shown after first grab)

### Metric Detail Sheet
Bottom sheet (slide up, swipe down to dismiss):
- Colored title bar + close button
- Current value large
- Sleep source tabs (only for sleep metric) — per-source bedtime/waketime, stage breakdown pills
- Chart: BarChart (bar metrics) or LineChart with box-and-whisker (line metrics)
- 7-day average
- Daily breakdown rows (most recent first)
- For line charts: tap a day to see raw readings with box stats
- Debug button → raw/computed JSON + share

### Location Detail Sheet
Page sheet modal:
- Current GPS coordinates
- Trail point count
- Location summary text (v2 `summaryRecent + summaryWeekly`, monospace)
- "Export Database" button
- Known Places section (collapsible):
  - List with delete buttons
  - Add form: name, lat, lng, radius, "Use Current" GPS button
  - JSON import form

### Settings Modal
Page sheet:
- **Location Tracking:** background toggle, retention days input, count + storage display
- **Debug: Raw Sleep Data:** fetch + display + share raw HealthKit sleep samples

### About Modal
Page sheet:
- Build info (git SHA, branch, timestamp, commit URL)
- OTA info (channel, runtime version, update ID)
- "Check for Updates" button
- Repository link

---

## 9. Charts

### BarChart
View-based, 200px height. Today = full color, past = 30% opacity. Null days = small dash. Unit label below.

### LineChart
Handles both simple dots (DailyValue) and box-and-whisker (HeartRateDaily). For HR: whisker (min–max), box (Q1–Q3), median line. Tappable days. Count label above whiskers.

### BoxPlot (inline, in metric cards)
Horizontal, 24px height. Two rows: dot row (individual values as 4px circles) + plot row (whiskers p5–p25 and p75–p95, box p25–p75, median line). Positions as percentages of range.

---

## 10. Known Places CRUD

```swift
struct KnownPlace: Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}
```

- **List:** `SELECT ... ORDER BY name ASC`
- **Add:** INSERT with validation (name required, lat -90..90, lng -180..180)
- **Delete:** DELETE by id
- **Import JSON:** Accepts array or `{knownPlaces:[...]}` wrapper. Field aliases: `lat`/`latitude`, `lon`/`lng`/`longitude`
- **"Use Current":** Requests high-accuracy GPS fix, rejects reads older than 30 seconds

### Matching Algorithm
For each GPS point, check all known places. Return closest within-radius (or -1). Ties broken by distance. O(n*k).

---

## 11. App Lifecycle

1. **On launch:** Open DB → run migrations → load settings → prune old locations → load known places → auto-grab context
2. **On foreground:** Re-prune locations
3. **On background location event:** INSERT GPS point(s) into `locations` table
4. **On retention days change:** Debounced 1-second prune

---

## 12. Formatting Utilities

- `formatTime("2026-03-15T23:00:00Z")` → `"11pm"` or `"11:30pm"` (UTC hours)
- `formatNumber(8241)` → `"8,241"` (locale comma formatting)
- `buildSummary(health, locationCount)` → one-liner banner string
- `formatLocalTime(utcMs)` → `"Mon 10:00pm"` (local time)
- `formatDateKey(date)` → `"2026-03-15"` (local time, not UTC — intentional)
- `dayOfWeek("2026-03-15")` → `"Sunday"` (local time)

**Critical:** Day bucketing uses local time (`getFullYear/getMonth/getDate`), not UTC. "Your steps today" means your local today.

---

## 13. Key Implementation Decisions for Swift Port

1. **Sleep window is noon-to-noon.** Not midnight-to-midnight. Required for overnight sessions.
2. **Sleep merges overlapping intervals before summing.** Watch + iPhone both report same period.
3. **Today is always live, past days are cached.** Cache key is `(metric, "YYYY-MM-DD")`.
4. **Day bucketing uses local time.** `DateFormatter` with local timezone, not UTC.
5. **Background location uses CLLocationManager delegate.** Register for significant location changes.
6. **Heart rate is different from other metrics.** Uses HeartRateDaily with full distribution stats, rendered as box-and-whisker.
7. **Clustering is computed on-demand.** Not on grab — only when user opens Location sheet or shares.
8. **Export JSON shape is a contract.** AI consumers expect the `SummaryExport` structure. Do not change field names.
9. **Dwell time gap cap: 2 hours** in cluster-level stats (prevents overnight inflation).
10. **All HealthKit queries are fire-and-forget.** Individual metric failure returns nil, does not block other metrics.

---

## 14. Permissions Required

### Info.plist
```xml
NSHealthShareUsageDescription — read health data for AI coaching
NSLocationWhenInUseUsageDescription — current GPS for context snapshot
NSLocationAlwaysAndWhenInUseUsageDescription — background location trail
UIBackgroundModes — location
```

### HealthKit Entitlement
Read access to: StepCount, HeartRate, ActiveEnergyBurned, DistanceWalkingRunning, SleepAnalysis, BodyMass, MindfulSession, HeartRateVariabilitySDNN, RestingHeartRate, AppleExerciseTime.

---

## 15. Bundle & Identity

- Bundle ID: `com.idvorkin.contextgrabber`
- App name: "Context Grabber"
- Min deployment target: iOS 15.1

---

## 16. Test Behavioral Contracts

Tests verify pure functions only — no device/HealthKit mocking. Key contracts:

| Area | Contract |
|------|----------|
| Sleep | Overlapping intervals are merged before summing; InBed (0) and Awake (2) excluded; empty → null |
| Weight | Most recent sample returned; `countWeightDays` counts distinct local-time dates |
| Meditation | Sum of session durations; negative durations clamped to 0 |
| Heart rate aggregation | Per-day min/max/avg/q1/median/q3 using R-7 percentile |
| Clustering v2 | Stays at same location across long gaps are preserved; short visits (<5min) filtered; same physical location on different days gets same Place ID |
| Box plot stats | R-7 linear interpolation percentile; null if no finite values |
| Pruning | Threshold = `now - retentionDays * 86400000` |
| Summary builder | Null metrics omitted; pipe-separated |

---

## 17. File Map (Current → Swift)

| Current | Purpose | Swift Equivalent |
|---------|---------|-----------------|
| `App.tsx` | All app logic + UI | Split into ViewModels + Views |
| `lib/health.ts` | HealthKit processing | `HealthService.swift` |
| `lib/sleep.ts` | Sleep detail extraction | Part of `HealthService.swift` |
| `lib/weekly.ts` | Weekly aggregation | `WeeklyAggregator.swift` |
| `lib/healthCache.ts` | Cache layer | `HealthCache.swift` (SwiftData) |
| `lib/clustering_v2.ts` | Stay detection | `LocationClustering.swift` |
| `lib/places.ts` | Known place matching | `PlaceManager.swift` |
| `lib/geo.ts` | Haversine | `GeoUtils.swift` |
| `lib/stats.ts` | Box plot stats | `Statistics.swift` |
| `lib/share.ts` | Export formatting | `ExportService.swift` |
| `lib/summary.ts` | Text formatting | `Formatters.swift` |
| `lib/location.ts` | Pruning logic | Part of `LocationService.swift` |
| `components/MetricDetailSheet.tsx` | Detail sheet | `MetricDetailView.swift` |
| `components/BarChart.tsx` | Bar chart | SwiftUI `Chart` or custom |
| `components/LineChart.tsx` | Line/whisker chart | SwiftUI `Chart` or custom |
| `components/BoxPlot.tsx` | Inline box plot | Custom SwiftUI view |
