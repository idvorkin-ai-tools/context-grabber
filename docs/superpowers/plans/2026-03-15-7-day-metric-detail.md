# 7-Day Metric Detail View Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tap-to-drill-down on metric cards showing a 7-day chart and daily breakdown for each health metric.

**Architecture:** New `lib/weekly.ts` for pure data aggregation functions, new `components/` directory with `MetricDetailSheet`, `BarChart`, and `LineChart` components. HealthKit weekly queries live in `App.tsx` alongside existing health queries. Single `Animated.Value` drives a slide-up sheet overlay.

**Tech Stack:** React Native Animated API, pure RN Views for charts, existing HealthKit library (`@kingstinct/react-native-healthkit`), Jest + ts-jest for testing.

**Spec:** `docs/superpowers/specs/2026-03-15-7-day-metric-detail-design.md`

---

## Chunk 1: Data Layer (`lib/weekly.ts` + tests)

### Task 1: Types and configuration — `lib/weekly.ts`

**Files:**
- Create: `lib/weekly.ts`
- Test: `__tests__/weekly.test.ts`

- [ ] **Step 1: Create `lib/weekly.ts` with types and METRIC_CONFIG**

```typescript
// lib/weekly.ts

export type MetricKey =
  | "steps"
  | "heartRate"
  | "sleep"
  | "activeEnergy"
  | "walkingDistance"
  | "weight"
  | "meditation";

export type ChartType = "bar" | "line";

export type MetricConfig = {
  label: string;
  unit: string;
  color: string;
  chartType: ChartType;
  sublabel: string;
};

export const METRIC_CONFIG: Record<MetricKey, MetricConfig> = {
  steps: {
    label: "Steps",
    unit: "steps",
    color: "#4cc9f0",
    chartType: "bar",
    sublabel: "today",
  },
  heartRate: {
    label: "Heart Rate",
    unit: "bpm",
    color: "#f72585",
    chartType: "line",
    sublabel: "latest",
  },
  sleep: {
    label: "Sleep",
    unit: "hrs",
    color: "#7b2cbf",
    chartType: "bar",
    sublabel: "last night",
  },
  activeEnergy: {
    label: "Active Energy",
    unit: "kcal",
    color: "#ff9e00",
    chartType: "bar",
    sublabel: "today",
  },
  walkingDistance: {
    label: "Walking Distance",
    unit: "km",
    color: "#06d6a0",
    chartType: "bar",
    sublabel: "today",
  },
  weight: {
    label: "Weight",
    unit: "kg",
    color: "#4895ef",
    chartType: "line",
    sublabel: "latest",
  },
  meditation: {
    label: "Meditation",
    unit: "min",
    color: "#e0aaff",
    chartType: "bar",
    sublabel: "today",
  },
};

export type DailyValue = {
  date: string; // "YYYY-MM-DD"
  value: number | null;
};

export type HeartRateDaily = {
  date: string; // "YYYY-MM-DD"
  avg: number | null;
  min: number | null;
  max: number | null;
};
```

- [ ] **Step 2: Verify file compiles**

Run: `npx tsc --noEmit lib/weekly.ts`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/weekly.ts
git commit -m "feat: add weekly types and metric config"
```

---

### Task 2: `bucketByDay` — generic day-bucketing

**Files:**
- Modify: `lib/weekly.ts`
- Create: `__tests__/weekly.test.ts`

- [ ] **Step 1: Write failing tests for `bucketByDay`**

Create `__tests__/weekly.test.ts`:

```typescript
import { bucketByDay, type DailyValue } from "../lib/weekly";

describe("bucketByDay", () => {
  it("returns 7 days with null values when no samples", () => {
    const result = bucketByDay([], new Date(2026, 2, 15), 7, (items) =>
      items.length > 0 ? items.reduce((a, b) => a + b, 0) : null,
    );
    expect(result).toHaveLength(7);
    expect(result.every((d) => d.value === null)).toBe(true);
    expect(result[0].date).toBe("2026-03-09");
    expect(result[6].date).toBe("2026-03-15");
  });

  it("buckets samples into correct days", () => {
    const samples = [
      { date: new Date("2026-03-15T10:00:00Z"), value: 100 },
      { date: new Date("2026-03-15T14:00:00Z"), value: 200 },
      { date: new Date("2026-03-14T08:00:00Z"), value: 50 },
    ];
    const result = bucketByDay(
      samples,
      new Date(2026, 2, 15),
      7,
      (items) => (items.length > 0 ? items.reduce((a, b) => a + b, 0) : null),
    );
    // Mar 15 = index 6, Mar 14 = index 5
    expect(result[6].value).toBe(300);
    expect(result[5].value).toBe(50);
    expect(result[4].value).toBeNull(); // Mar 13
  });

  it("ignores samples outside the date range", () => {
    const samples = [
      { date: new Date("2026-03-01T10:00:00Z"), value: 999 },
      { date: new Date("2026-03-15T10:00:00Z"), value: 100 },
    ];
    const result = bucketByDay(
      samples,
      new Date(2026, 2, 15),
      7,
      (items) => (items.length > 0 ? items.reduce((a, b) => a + b, 0) : null),
    );
    expect(result[6].value).toBe(100);
    // Mar 1 is outside the 7-day window, should not appear
    expect(result.every((d, i) => i === 6 || d.value === null)).toBe(true);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: FAIL — `bucketByDay` not found

- [ ] **Step 3: Implement `bucketByDay`**

Add to `lib/weekly.ts`:

```typescript
/**
 * Format a Date as "YYYY-MM-DD" in local time.
 * Uses local time to match HealthKit's day boundaries (consistent with grabHealthData).
 */
export function formatDateKey(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Generic day-bucketing. Takes samples with a date and numeric value,
 * buckets them into `days` calendar days ending at `endDate`,
 * and applies `aggregate` to each day's values.
 */
export function bucketByDay(
  samples: { date: Date; value: number }[],
  endDate: Date,
  days: number,
  aggregate: (values: number[]) => number | null,
): DailyValue[] {
  // Build date keys for each day in range
  const result: DailyValue[] = [];
  const buckets = new Map<string, number[]>();

  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    result.push({ date: key, value: null });
    buckets.set(key, []);
  }

  // Sort samples into buckets
  for (const sample of samples) {
    const key = formatDateKey(sample.date);
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(sample.value);
    }
  }

  // Aggregate each bucket
  for (const day of result) {
    const bucket = buckets.get(day.date)!;
    day.value = aggregate(bucket);
  }

  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: PASS — all 3 tests

- [ ] **Step 5: Commit**

```bash
git add lib/weekly.ts __tests__/weekly.test.ts
git commit -m "feat: add bucketByDay generic day-bucketing function"
```

---

### Task 3: `computeAverage`

**Files:**
- Modify: `lib/weekly.ts`
- Modify: `__tests__/weekly.test.ts`

- [ ] **Step 1: Write failing tests for `computeAverage`**

Append to `__tests__/weekly.test.ts`:

```typescript
import { computeAverage } from "../lib/weekly";

describe("computeAverage", () => {
  it("returns null for empty array", () => {
    expect(computeAverage([])).toBeNull();
  });

  it("returns null when all values are null", () => {
    expect(
      computeAverage([
        { date: "2026-03-15", value: null },
        { date: "2026-03-14", value: null },
      ]),
    ).toBeNull();
  });

  it("averages non-null values, ignoring nulls", () => {
    const result = computeAverage([
      { date: "2026-03-15", value: 100 },
      { date: "2026-03-14", value: null },
      { date: "2026-03-13", value: 200 },
    ]);
    expect(result).toBe(150);
  });

  it("rounds to one decimal place", () => {
    const result = computeAverage([
      { date: "2026-03-15", value: 10 },
      { date: "2026-03-14", value: 10 },
      { date: "2026-03-13", value: 11 },
    ]);
    expect(result).toBe(10.3);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: FAIL — `computeAverage` not found

- [ ] **Step 3: Implement `computeAverage`**

Add to `lib/weekly.ts`:

```typescript
/**
 * Compute the average of non-null DailyValues.
 * Returns null if no non-null values exist.
 * Rounds to one decimal place.
 */
export function computeAverage(values: DailyValue[]): number | null {
  const nonNull = values.filter((v) => v.value !== null);
  if (nonNull.length === 0) return null;
  const sum = nonNull.reduce((acc, v) => acc + v.value!, 0);
  return Math.round((sum / nonNull.length) * 10) / 10;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/weekly.ts __tests__/weekly.test.ts
git commit -m "feat: add computeAverage for 7-day summary line"
```

---

### Task 4: `aggregateHeartRate`

**Files:**
- Modify: `lib/weekly.ts`
- Modify: `__tests__/weekly.test.ts`

- [ ] **Step 1: Write failing tests**

Append to `__tests__/weekly.test.ts`:

```typescript
import { aggregateHeartRate, type HeartRateDaily } from "../lib/weekly";

describe("aggregateHeartRate", () => {
  it("returns 7 days with null values when no samples", () => {
    const result = aggregateHeartRate([], new Date(2026, 2, 15));
    expect(result).toHaveLength(7);
    expect(result[0]).toEqual({
      date: "2026-03-09",
      avg: null,
      min: null,
      max: null,
    });
  });

  it("computes avg/min/max per day", () => {
    const samples = [
      { date: new Date("2026-03-15T10:00:00Z"), value: 60 },
      { date: new Date("2026-03-15T14:00:00Z"), value: 80 },
      { date: new Date("2026-03-15T18:00:00Z"), value: 100 },
    ];
    const result = aggregateHeartRate(samples, new Date(2026, 2, 15));
    const today = result[6];
    expect(today.avg).toBe(80);
    expect(today.min).toBe(60);
    expect(today.max).toBe(100);
  });

  it("handles single reading per day", () => {
    const samples = [
      { date: new Date("2026-03-14T08:00:00Z"), value: 72 },
    ];
    const result = aggregateHeartRate(samples, new Date(2026, 2, 15));
    const yesterday = result[5];
    expect(yesterday.avg).toBe(72);
    expect(yesterday.min).toBe(72);
    expect(yesterday.max).toBe(72);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: FAIL — `aggregateHeartRate` not found

- [ ] **Step 3: Implement `aggregateHeartRate`**

Add to `lib/weekly.ts`:

```typescript
/**
 * Aggregate heart rate samples into daily avg/min/max.
 */
export function aggregateHeartRate(
  samples: { date: Date; value: number }[],
  endDate: Date,
): HeartRateDaily[] {
  const result: HeartRateDaily[] = [];
  const buckets = new Map<string, number[]>();

  for (let i = 6; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    result.push({ date: key, avg: null, min: null, max: null });
    buckets.set(key, []);
  }

  for (const sample of samples) {
    const key = formatDateKey(sample.date);
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(sample.value);
    }
  }

  for (const day of result) {
    const bucket = buckets.get(day.date)!;
    if (bucket.length > 0) {
      day.avg = Math.round(bucket.reduce((a, b) => a + b, 0) / bucket.length);
      day.min = Math.min(...bucket);
      day.max = Math.max(...bucket);
    }
  }

  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/weekly.ts __tests__/weekly.test.ts
git commit -m "feat: add aggregateHeartRate for daily avg/min/max"
```

---

### Task 5: `aggregateSleep`

**Files:**
- Modify: `lib/weekly.ts`
- Modify: `__tests__/weekly.test.ts`

The sleep aggregation reuses the overlap-merge algorithm from `lib/health.ts` (`calculateSleepHours`). Import `SleepSample` type and `calculateSleepHours` from `lib/health.ts`.

- [ ] **Step 1: Write failing tests**

Append to `__tests__/weekly.test.ts`:

```typescript
import { aggregateSleep } from "../lib/weekly";

describe("aggregateSleep", () => {
  it("returns 7 days with null when no samples", () => {
    const result = aggregateSleep([], new Date(2026, 2, 15));
    expect(result).toHaveLength(7);
    expect(result.every((d) => d.value === null)).toBe(true);
  });

  it("assigns sleep to the night's start date", () => {
    // Sleep from Mar 14 11pm to Mar 15 7am = 8hrs, assigned to Mar 14
    const samples = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ];
    const result = aggregateSleep(samples, new Date(2026, 2, 15));
    // Mar 14 is index 5 (6 days ago from Mar 15... wait: Mar 9=0, Mar 10=1, ..., Mar 14=5, Mar 15=6)
    expect(result[5].date).toBe("2026-03-14");
    expect(result[5].value).toBe(8);
    expect(result[6].value).toBeNull(); // Mar 15 has no sleep starting that night
  });

  it("merges overlapping samples from multiple sources per night", () => {
    const samples = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T23:30:00.000Z",
        endDate: "2026-03-15T06:30:00.000Z",
      },
    ];
    const result = aggregateSleep(samples, new Date(2026, 2, 15));
    expect(result[5].value).toBe(8); // merged, not 15
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: FAIL — `aggregateSleep` not found

- [ ] **Step 3: Implement `aggregateSleep`**

Add to `lib/weekly.ts`:

```typescript
import { calculateSleepHours, type SleepSample } from "./health";

/**
 * Aggregate sleep samples into daily hours.
 * Each sample is assigned to the local date of its startDate.
 * Uses calculateSleepHours (overlap-merge) per day.
 */
export function aggregateSleep(
  samples: SleepSample[],
  endDate: Date,
): DailyValue[] {
  const result: DailyValue[] = [];
  const buckets = new Map<string, SleepSample[]>();

  for (let i = 6; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    result.push({ date: key, value: null });
    buckets.set(key, []);
  }

  for (const sample of samples) {
    const key = formatDateKey(new Date(sample.startDate));
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(sample);
    }
  }

  for (const day of result) {
    const bucket = buckets.get(day.date)!;
    if (bucket.length > 0) {
      day.value = calculateSleepHours(bucket);
    }
  }

  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/weekly.ts __tests__/weekly.test.ts
git commit -m "feat: add aggregateSleep with per-night overlap merge"
```

---

### Task 6: `aggregateMeditation` and `pickLatestPerDay`

**Files:**
- Modify: `lib/weekly.ts`
- Modify: `__tests__/weekly.test.ts`

- [ ] **Step 1: Write failing tests**

Append to `__tests__/weekly.test.ts`:

```typescript
import { aggregateMeditation, pickLatestPerDay } from "../lib/weekly";

describe("aggregateMeditation", () => {
  it("returns 7 days with null when no sessions", () => {
    const result = aggregateMeditation([], new Date(2026, 2, 15));
    expect(result).toHaveLength(7);
    expect(result.every((d) => d.value === null)).toBe(true);
  });

  it("sums session minutes per day", () => {
    const sessions = [
      {
        startDate: "2026-03-15T08:00:00.000Z",
        endDate: "2026-03-15T08:10:00.000Z", // 10 min
      },
      {
        startDate: "2026-03-15T12:00:00.000Z",
        endDate: "2026-03-15T12:20:00.000Z", // 20 min
      },
    ];
    const result = aggregateMeditation(sessions, new Date(2026, 2, 15));
    expect(result[6].value).toBe(30);
  });

  it("clamps negative durations to zero", () => {
    const sessions = [
      {
        startDate: "2026-03-15T12:00:00.000Z",
        endDate: "2026-03-15T11:00:00.000Z", // negative
      },
    ];
    const result = aggregateMeditation(sessions, new Date(2026, 2, 15));
    expect(result[6].value).toBe(0);
  });
});

describe("pickLatestPerDay", () => {
  it("returns 7 days with null when no samples", () => {
    const result = pickLatestPerDay([], new Date(2026, 2, 15));
    expect(result).toHaveLength(7);
    expect(result.every((d) => d.value === null)).toBe(true);
  });

  it("picks latest sample when multiple per day", () => {
    const samples = [
      { date: new Date("2026-03-15T08:00:00Z"), value: 75.0 },
      { date: new Date("2026-03-15T20:00:00Z"), value: 75.5 }, // latest
    ];
    const result = pickLatestPerDay(samples, new Date(2026, 2, 15));
    expect(result[6].value).toBe(75.5);
  });

  it("handles missing days", () => {
    const samples = [
      { date: new Date("2026-03-15T08:00:00Z"), value: 75.0 },
      { date: new Date("2026-03-12T08:00:00Z"), value: 74.5 },
    ];
    const result = pickLatestPerDay(samples, new Date(2026, 2, 15));
    expect(result[6].value).toBe(75.0); // Mar 15
    expect(result[3].value).toBe(74.5); // Mar 12
    expect(result[4].value).toBeNull(); // Mar 13 — gap
    expect(result[5].value).toBeNull(); // Mar 14 — gap
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: FAIL

- [ ] **Step 3: Implement both functions**

Add to `lib/weekly.ts`:

```typescript
import type { MindfulSession } from "./health";

/**
 * Aggregate mindful sessions into daily minutes. No overlap merge.
 * Clamps negative durations to zero.
 */
export function aggregateMeditation(
  sessions: MindfulSession[],
  endDate: Date,
): DailyValue[] {
  const result: DailyValue[] = [];
  const buckets = new Map<string, MindfulSession[]>();

  for (let i = 6; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    result.push({ date: key, value: null });
    buckets.set(key, []);
  }

  for (const session of sessions) {
    const key = formatDateKey(new Date(session.startDate));
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(session);
    }
  }

  for (const day of result) {
    const bucket = buckets.get(day.date)!;
    if (bucket.length > 0) {
      const totalMs = bucket.reduce((acc, s) => {
        const start = new Date(s.startDate).getTime();
        const end = new Date(s.endDate).getTime();
        return acc + Math.max(0, end - start);
      }, 0);
      day.value = Math.round((totalMs / (1000 * 60)) * 10) / 10;
    }
  }

  return result;
}

/**
 * Pick the latest sample per day (for weight).
 * Samples should have { date: Date, value: number }.
 */
export function pickLatestPerDay(
  samples: { date: Date; value: number }[],
  endDate: Date,
): DailyValue[] {
  const result: DailyValue[] = [];
  const buckets = new Map<string, { date: Date; value: number }[]>();

  for (let i = 6; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    result.push({ date: key, value: null });
    buckets.set(key, []);
  }

  for (const sample of samples) {
    const key = formatDateKey(sample.date);
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(sample);
    }
  }

  for (const day of result) {
    const bucket = buckets.get(day.date)!;
    if (bucket.length > 0) {
      // Sort by date descending, pick first (latest)
      bucket.sort((a, b) => b.date.getTime() - a.date.getTime());
      day.value = Math.round(bucket[0].value * 100) / 100;
    }
  }

  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest __tests__/weekly.test.ts --verbose`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/weekly.ts __tests__/weekly.test.ts
git commit -m "feat: add aggregateMeditation and pickLatestPerDay"
```

---

### Task 7: Run full test suite

- [ ] **Step 1: Run all tests**

Run: `npx jest --verbose`
Expected: All existing tests PASS, all new weekly tests PASS

- [ ] **Step 2: Fix any failures if needed**

---

## Chunk 2: Chart Components

### Task 8: `BarChart` component

**Files:**
- Create: `components/BarChart.tsx`

This is a pure React Native component. No HealthKit. Takes `DailyValue[]` and an accent color, renders 7 vertical bars.

- [ ] **Step 1: Create `components/` directory and `BarChart.tsx`**

```typescript
// components/BarChart.tsx
import { View, Text, StyleSheet } from "react-native";
import { formatDateKey, type DailyValue } from "../lib/weekly";

type BarChartProps = {
  data: DailyValue[];
  color: string;
  unit: string;
};

const CHART_HEIGHT = 200;
const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function getDayLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  return DAY_LABELS[d.getUTCDay() === 0 ? 6 : d.getUTCDay() - 1];
}

export default function BarChart({ data, color, unit }: BarChartProps) {
  const maxValue = Math.max(...data.map((d) => d.value ?? 0), 1);
  const today = formatDateKey(new Date());

  return (
    <View style={styles.container}>
      <View style={styles.barsRow}>
        {data.map((day) => {
          const height =
            day.value != null ? (day.value / maxValue) * CHART_HEIGHT : 0;
          const isToday = day.date === today;
          const barColor = isToday ? color : color + "4D"; // 30% opacity

          return (
            <View key={day.date} style={styles.barColumn}>
              <View style={styles.barWrapper}>
                {day.value != null ? (
                  <View
                    style={[
                      styles.bar,
                      {
                        height,
                        backgroundColor: barColor,
                      },
                    ]}
                  />
                ) : (
                  <View style={styles.noData} />
                )}
              </View>
              <Text style={styles.dayLabel}>{getDayLabel(day.date)}</Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: CHART_HEIGHT + 30,
    paddingHorizontal: 8,
  },
  barsRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-end",
    height: CHART_HEIGHT,
  },
  barColumn: {
    flex: 1,
    alignItems: "center",
  },
  barWrapper: {
    flex: 1,
    justifyContent: "flex-end",
    width: "100%",
    paddingHorizontal: 4,
  },
  bar: {
    width: "100%",
    borderTopLeftRadius: 6,
    borderTopRightRadius: 6,
    minHeight: 4,
  },
  noData: {
    height: 2,
    width: "60%",
    backgroundColor: "#333",
    borderRadius: 1,
    alignSelf: "center",
  },
  dayLabel: {
    fontSize: 11,
    color: "#666",
    marginTop: 6,
  },
});
```

- [ ] **Step 2: Verify it compiles**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add components/BarChart.tsx
git commit -m "feat: add BarChart component for 7-day bar visualization"
```

---

### Task 9: `LineChart` component

**Files:**
- Create: `components/LineChart.tsx`

Renders dots connected by lines. Supports both `DailyValue[]` (weight) and `HeartRateDaily[]` (heart rate with min/max range band).

- [ ] **Step 1: Create `components/LineChart.tsx`**

```typescript
// components/LineChart.tsx
import { View, Text, StyleSheet } from "react-native";
import { formatDateKey, type DailyValue, type HeartRateDaily } from "../lib/weekly";

type LineChartProps = {
  data: DailyValue[] | HeartRateDaily[];
  color: string;
  unit: string;
};

const CHART_HEIGHT = 200;
const DOT_SIZE = 8;
const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function getDayLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  return DAY_LABELS[d.getUTCDay() === 0 ? 6 : d.getUTCDay() - 1];
}

function isHeartRateData(data: (DailyValue | HeartRateDaily)[]): data is HeartRateDaily[] {
  return data.length > 0 && "avg" in data[0];
}

export default function LineChart({ data, color, unit }: LineChartProps) {
  const isHR = isHeartRateData(data);

  // Get all values for computing range
  const allValues: number[] = [];
  for (const d of data) {
    if (isHR) {
      const hr = d as HeartRateDaily;
      if (hr.min != null) allValues.push(hr.min);
      if (hr.max != null) allValues.push(hr.max);
      if (hr.avg != null) allValues.push(hr.avg);
    } else {
      const dv = d as DailyValue;
      if (dv.value != null) allValues.push(dv.value);
    }
  }

  if (allValues.length === 0) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No data</Text>
        </View>
      </View>
    );
  }

  const minVal = Math.min(...allValues);
  const maxVal = Math.max(...allValues);
  const range = maxVal - minVal || 1;
  const padding = range * 0.1;
  const effectiveMin = minVal - padding;
  const effectiveRange = range + padding * 2;

  function yPos(val: number): number {
    return CHART_HEIGHT - ((val - effectiveMin) / effectiveRange) * CHART_HEIGHT;
  }

  const today = formatDateKey(new Date());

  return (
    <View style={styles.container}>
      <View style={styles.chartArea}>
        {/* Heart rate range bands */}
        {isHR &&
          (data as HeartRateDaily[]).map((d, i) => {
            if (d.min == null || d.max == null) return null;
            const top = yPos(d.max);
            const bottom = yPos(d.min);
            const left = `${(i / (data.length - 1 || 1)) * 100}%`;
            return (
              <View
                key={`range-${d.date}`}
                style={[
                  styles.rangeBand,
                  {
                    top,
                    height: bottom - top,
                    left,
                    backgroundColor: color + "26", // 15% opacity
                  },
                ]}
              />
            );
          })}

        {/* Dots */}
        {data.map((d, i) => {
          const val = isHR ? (d as HeartRateDaily).avg : (d as DailyValue).value;
          if (val == null) return null;
          const top = yPos(val) - DOT_SIZE / 2;
          const left = `${(i / (data.length - 1 || 1)) * 100}%`;
          const isToday = d.date === today;

          return (
            <View
              key={`dot-${d.date}`}
              style={[
                styles.dot,
                {
                  top,
                  left,
                  backgroundColor: isToday ? color : color + "99",
                  borderColor: isToday ? "#fff" : "transparent",
                },
              ]}
            />
          );
        })}

        {/* Note: Connecting lines between dots are omitted for simplicity.
            The dots + range bands convey the trend effectively. */}
      </View>

      {/* Day labels */}
      <View style={styles.labelsRow}>
        {data.map((d) => (
          <View key={`label-${d.date}`} style={styles.labelColumn}>
            <Text style={styles.dayLabel}>{getDayLabel(d.date)}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: CHART_HEIGHT + 30,
    paddingHorizontal: 8,
  },
  chartArea: {
    height: CHART_HEIGHT,
    position: "relative",
  },
  emptyContainer: {
    height: CHART_HEIGHT,
    justifyContent: "center",
    alignItems: "center",
  },
  emptyText: {
    color: "#555",
    fontSize: 14,
  },
  rangeBand: {
    position: "absolute",
    width: 20,
    borderRadius: 4,
    marginLeft: -10,
  },
  dot: {
    position: "absolute",
    width: DOT_SIZE,
    height: DOT_SIZE,
    borderRadius: DOT_SIZE / 2,
    marginLeft: -DOT_SIZE / 2,
    borderWidth: 1.5,
  },
  labelsRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: 6,
  },
  labelColumn: {
    flex: 1,
    alignItems: "center",
  },
  dayLabel: {
    fontSize: 11,
    color: "#666",
  },
});
```

- [ ] **Step 2: Verify it compiles**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add components/LineChart.tsx
git commit -m "feat: add LineChart component for heart rate and weight"
```

---

## Chunk 3: MetricDetailSheet Component

### Task 10: `MetricDetailSheet` component

**Files:**
- Create: `components/MetricDetailSheet.tsx`

This is the full-screen slide-up sheet with animation, PanResponder, header, chart, average line, and daily breakdown.

- [ ] **Step 1: Create `components/MetricDetailSheet.tsx`**

```typescript
// components/MetricDetailSheet.tsx
import { useEffect, useRef } from "react";
import {
  View,
  Text,
  StyleSheet,
  Animated,
  Dimensions,
  Easing,
  PanResponder,
  ScrollView,
  TouchableOpacity,
  TouchableWithoutFeedback,
  ActivityIndicator,
} from "react-native";
import {
  METRIC_CONFIG,
  computeAverage,
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
} from "../lib/weekly";
import { formatNumber } from "../lib/summary";
import BarChart from "./BarChart";
import LineChart from "./LineChart";

type MetricDetailSheetProps = {
  metricKey: MetricKey;
  currentValue: string;
  currentSublabel: string;
  data: DailyValue[] | HeartRateDaily[] | null; // null = loading
  error: string | null;
  onClose: () => void;
};

const { height: SCREEN_HEIGHT } = Dimensions.get("window");

function formatDailyValue(
  day: DailyValue | HeartRateDaily,
  unit: string,
): string {
  if ("avg" in day) {
    const hr = day as HeartRateDaily;
    if (hr.avg == null) return "\u2014";
    return `${hr.avg} avg (${hr.min}\u2013${hr.max})`;
  }
  const dv = day as DailyValue;
  if (dv.value == null) return "\u2014";
  if (unit === "steps" || unit === "kcal") return formatNumber(dv.value);
  return `${dv.value}`;
}

function formatDayRow(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${days[d.getUTCDay()]}, ${months[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

export default function MetricDetailSheet({
  metricKey,
  currentValue,
  currentSublabel,
  data,
  error,
  onClose,
}: MetricDetailSheetProps) {
  const config = METRIC_CONFIG[metricKey];
  const slideAnim = useRef(new Animated.Value(SCREEN_HEIGHT)).current;

  // Slide up on mount
  useEffect(() => {
    Animated.timing(slideAnim, {
      toValue: 0,
      duration: 300,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [slideAnim]);

  function dismiss() {
    Animated.timing(slideAnim, {
      toValue: SCREEN_HEIGHT,
      duration: 250,
      easing: Easing.in(Easing.cubic),
      useNativeDriver: true,
    }).start(() => onClose());
  }

  // PanResponder for swipe-to-dismiss on header+chart
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => false,
      onMoveShouldSetPanResponder: (_, gestureState) =>
        gestureState.dy > 10,
      onPanResponderMove: (_, gestureState) => {
        if (gestureState.dy > 0) {
          slideAnim.setValue(gestureState.dy);
        }
      },
      onPanResponderRelease: (_, gestureState) => {
        if (gestureState.dy > 100) {
          dismiss();
        } else {
          Animated.timing(slideAnim, {
            toValue: 0,
            duration: 200,
            useNativeDriver: true,
          }).start();
        }
      },
    }),
  ).current;

  const overlayOpacity = slideAnim.interpolate({
    inputRange: [0, SCREEN_HEIGHT],
    outputRange: [0.6, 0],
    extrapolate: "clamp",
  });

  // Compute average
  let avgText: string | null = null;
  if (data) {
    if (config.chartType === "line" && "avg" in (data[0] || {})) {
      // Heart rate: average of avgs
      const hrData = data as HeartRateDaily[];
      const asDailyValues: DailyValue[] = hrData.map((d) => ({
        date: d.date,
        value: d.avg,
      }));
      const avg = computeAverage(asDailyValues);
      if (avg != null) avgText = `Avg: ${avg} ${config.unit}/day`;
    } else {
      const avg = computeAverage(data as DailyValue[]);
      if (avg != null) {
        const formatted =
          config.unit === "steps" || config.unit === "kcal"
            ? formatNumber(Math.round(avg))
            : `${avg}`;
        avgText = `Avg: ${formatted} ${config.unit}/day`;
      }
    }
  }

  // Daily breakdown (reversed: most recent first)
  const reversedData = data ? [...data].reverse() : [];

  return (
    <View style={StyleSheet.absoluteFill}>
      {/* Overlay — blocks taps on underlying UI */}
      <TouchableWithoutFeedback onPress={dismiss}>
        <Animated.View
          style={[styles.overlay, { opacity: overlayOpacity }]}
        />
      </TouchableWithoutFeedback>

      {/* Sheet */}
      <Animated.View
        style={[
          styles.sheet,
          { transform: [{ translateY: slideAnim }] },
        ]}
      >
        {/* Header + Chart zone (PanResponder) */}
        <View {...panResponder.panHandlers}>
          {/* Drag handle */}
          <View style={styles.dragHandleContainer}>
            <View style={styles.dragHandle} />
          </View>

          {/* Header */}
          <View style={styles.header}>
            <View style={styles.headerLeft}>
              <Text style={[styles.metricName, { color: config.color }]}>
                {config.label}
              </Text>
            </View>
            <TouchableOpacity onPress={dismiss} style={styles.closeButton}>
              <Text style={styles.closeText}>✕</Text>
            </TouchableOpacity>
          </View>

          <Text style={styles.currentValue}>{currentValue}</Text>
          <Text style={styles.sublabel}>{currentSublabel}</Text>

          {/* Chart */}
          <View style={styles.chartContainer}>
            {error ? (
              <View style={styles.errorContainer}>
                <Text style={styles.errorText}>{error}</Text>
              </View>
            ) : !data ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={config.color} />
              </View>
            ) : config.chartType === "bar" ? (
              <BarChart
                data={data as DailyValue[]}
                color={config.color}
                unit={config.unit}
              />
            ) : (
              <LineChart data={data} color={config.color} unit={config.unit} />
            )}
          </View>

          {/* Average */}
          {avgText && (
            <Text style={[styles.avgText, { color: config.color }]}>
              {avgText}
            </Text>
          )}
        </View>

        {/* Daily Breakdown (separate ScrollView) */}
        <ScrollView style={styles.breakdownScroll}>
          <View style={styles.breakdownContainer}>
            {reversedData.map((day, i) => (
              <View
                key={day.date}
                style={[
                  styles.breakdownRow,
                  i < reversedData.length - 1 && styles.breakdownDivider,
                ]}
              >
                <Text style={styles.breakdownDay}>
                  {formatDayRow(day.date)}
                </Text>
                <Text
                  style={[
                    styles.breakdownValue,
                    ("value" in day ? day.value : (day as HeartRateDaily).avg) ==
                      null && styles.breakdownValueNull,
                  ]}
                >
                  {formatDailyValue(day, config.unit)} {config.unit !== "steps" && config.unit !== "kcal" ? config.unit : ""}
                </Text>
              </View>
            ))}
          </View>
        </ScrollView>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "#000",
  },
  sheet: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "#111828",
  },
  dragHandleContainer: {
    alignItems: "center",
    paddingTop: 60,
    paddingBottom: 8,
  },
  dragHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#444",
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 20,
  },
  headerLeft: {
    flex: 1,
  },
  metricName: {
    fontSize: 16,
    fontWeight: "600",
  },
  closeButton: {
    padding: 8,
  },
  closeText: {
    fontSize: 20,
    color: "#888",
  },
  currentValue: {
    fontSize: 36,
    fontWeight: "bold",
    color: "#e0e0e0",
    paddingHorizontal: 20,
    marginTop: 4,
  },
  sublabel: {
    fontSize: 13,
    color: "#888",
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  chartContainer: {
    paddingHorizontal: 12,
  },
  loadingContainer: {
    height: 200,
    justifyContent: "center",
    alignItems: "center",
  },
  errorContainer: {
    height: 200,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 20,
  },
  errorText: {
    color: "#ff6b6b",
    fontSize: 14,
    textAlign: "center",
  },
  avgText: {
    fontSize: 14,
    fontWeight: "600",
    textAlign: "center",
    marginTop: 12,
    marginBottom: 16,
  },
  breakdownScroll: {
    flex: 1,
  },
  breakdownContainer: {
    paddingHorizontal: 20,
    paddingBottom: 40,
  },
  breakdownRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 14,
  },
  breakdownDivider: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#222",
  },
  breakdownDay: {
    fontSize: 15,
    fontWeight: "600",
    color: "#e0e0e0",
  },
  breakdownValue: {
    fontSize: 15,
    color: "#aaa",
  },
  breakdownValueNull: {
    color: "#555",
  },
});
```

- [ ] **Step 2: Verify it compiles**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add components/MetricDetailSheet.tsx
git commit -m "feat: add MetricDetailSheet slide-up component"
```

---

## Chunk 4: App.tsx Integration

### Task 11: Make MetricCard tappable

**Files:**
- Modify: `App.tsx`

- [ ] **Step 1: Import MetricKey type and add state**

At the top of `App.tsx`, add:

```typescript
import type { MetricKey } from "./lib/weekly";
```

Inside the App component, after existing state declarations, add:

```typescript
const [selectedMetric, setSelectedMetric] = useState<MetricKey | null>(null);
```

- [ ] **Step 2: Update MetricCardProps and MetricCard component**

Change the `MetricCardProps` type to add `metricKey` and `onPress`:

```typescript
type MetricCardProps = {
  metricKey: MetricKey;
  label: string;
  value: string;
  sublabel: string;
  fullWidth?: boolean;
  onPress: (key: MetricKey) => void;
};
```

Wrap `MetricCard` content in `TouchableOpacity`:

```typescript
function MetricCard({ metricKey, label, value, sublabel, fullWidth, onPress }: MetricCardProps) {
  const isNull = value === "\u2014";
  return (
    <TouchableOpacity
      style={[styles.metricCard, fullWidth && styles.metricCardFull]}
      onPress={() => onPress(metricKey)}
      activeOpacity={0.7}
    >
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, isNull && styles.metricValueNull]}>
        {value}
      </Text>
      <Text style={styles.metricSublabel}>{sublabel}</Text>
    </TouchableOpacity>
  );
}
```

- [ ] **Step 3: Update the metrics array to include metricKey**

Change the metrics array type and values. Replace the `MetricCardProps[]` type with an explicit type that includes `metricKey`:

```typescript
const metrics = snapshot
  ? [
      {
        metricKey: "steps" as MetricKey,
        label: "Steps",
        value: h?.steps != null ? formatNumber(h.steps) : "\u2014",
        sublabel: "today",
      },
      {
        metricKey: "heartRate" as MetricKey,
        label: "Heart Rate",
        value: h?.heartRate != null ? `${h.heartRate} bpm` : "\u2014",
        sublabel: "latest",
      },
      {
        metricKey: "sleep" as MetricKey,
        label: "Sleep",
        value: h?.sleepHours != null ? `${h.sleepHours} hrs` : "\u2014",
        sublabel:
          h?.bedtime && h?.wakeTime
            ? `${h.bedtime} \u2013 ${h.wakeTime}`
            : "last night",
      },
      {
        metricKey: "activeEnergy" as MetricKey,
        label: "Active Energy",
        value: h?.activeEnergy != null ? `${formatNumber(h.activeEnergy)} kcal` : "\u2014",
        sublabel: "today",
      },
      {
        metricKey: "walkingDistance" as MetricKey,
        label: "Walking Distance",
        value: h?.walkingDistance != null ? `${h.walkingDistance} km` : "\u2014",
        sublabel: "today",
      },
      {
        metricKey: "weight" as MetricKey,
        label: "Weight",
        value: h?.weight != null ? `${h.weight} kg` : "\u2014",
        sublabel:
          h?.weightDaysLast7 != null
            ? `${h.weightDaysLast7}/7 days weighed`
            : "latest",
      },
      {
        metricKey: "meditation" as MetricKey,
        label: "Meditation",
        value: h?.meditationMinutes != null ? `${h.meditationMinutes} min` : "\u2014",
        sublabel: "today",
      },
    ]
  : [];
```

- [ ] **Step 4: Update MetricCard rendering to pass new props**

In the JSX, add `metricKey` and `onPress` (we'll wire `onPress` to a placeholder for now):

```tsx
{metrics.map((m, i) => (
  <MetricCard
    key={m.label}
    metricKey={m.metricKey}
    label={m.label}
    value={m.value}
    sublabel={m.sublabel}
    fullWidth={metrics.length % 2 === 1 && i === metrics.length - 1}
    onPress={(key) => setSelectedMetric(key)}
  />
))}
```

- [ ] **Step 5: Commit**

```bash
git add App.tsx
git commit -m "feat: make MetricCard tappable with metricKey prop"
```

---

### Task 12: Add weekly data fetching and sheet state

**Files:**
- Modify: `App.tsx`

- [ ] **Step 1: Add new state variables**

After the existing state declarations in the App component, add:

```typescript
const [weeklyCache, setWeeklyCache] = useState<
  Partial<Record<MetricKey, DailyValue[] | HeartRateDaily[]>>
>({});
const [weeklyLoading, setWeeklyLoading] = useState(false);
const [weeklyError, setWeeklyError] = useState<string | null>(null);
```

- [ ] **Step 2: Add imports for weekly types and HealthKit queries**

Add to the top of `App.tsx`:

```typescript
import {
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
  aggregateHeartRate,
  aggregateSleep,
  aggregateMeditation,
  pickLatestPerDay,
} from "./lib/weekly";
import MetricDetailSheet from "./components/MetricDetailSheet";
```

- [ ] **Step 3: Add `grabWeeklyData` function**

Inside the App component, after `grabLocation`:

```typescript
async function grabWeeklyData(metric: MetricKey): Promise<DailyValue[] | HeartRateDaily[]> {
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const dateFilter = {
    date: { startDate: sevenDaysAgo, endDate: now },
  };

  switch (metric) {
    case "steps":
    case "activeEnergy":
    case "walkingDistance": {
      const identifier =
        metric === "steps"
          ? QTI.stepCount
          : metric === "activeEnergy"
            ? QTI.activeEnergy
            : QTI.distance;
      // Query all 7 days in parallel (local time boundaries, matching grabHealthData)
      const dayPromises = Array.from({ length: 7 }, (_, idx) => {
        const i = 6 - idx;
        const dayStart = new Date(now);
        dayStart.setDate(dayStart.getDate() - i);
        dayStart.setHours(0, 0, 0, 0);
        const dayEnd = new Date(dayStart);
        dayEnd.setHours(23, 59, 59, 999);
        const dateKey = `${dayStart.getFullYear()}-${String(dayStart.getMonth() + 1).padStart(2, "0")}-${String(dayStart.getDate()).padStart(2, "0")}`;
        return HealthKit.queryStatisticsForQuantity(
          identifier,
          ["cumulativeSum"],
          { filter: { date: { startDate: dayStart, endDate: dayEnd } } },
        )
          .then((result) => ({
            date: dateKey,
            value: result?.sumQuantity?.quantity != null
              ? Math.round(result.sumQuantity.quantity * 100) / 100
              : null,
          }))
          .catch(() => ({ date: dateKey, value: null }));
      });
      return Promise.all(dayPromises);
    }

    case "heartRate": {
      const samples = await HealthKit.queryQuantitySamples(QTI.heartRate, {
        limit: 0,
        filter: dateFilter,
      });
      const mapped = samples.map((s: any) => ({
        date: new Date(s.startDate),
        value: s.quantity,
      }));
      return aggregateHeartRate(mapped, now);
    }

    case "sleep": {
      const samples = await HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: dateFilter,
      });
      return aggregateSleep(samples, now);
    }

    case "weight": {
      const samples = await HealthKit.queryQuantitySamples(QTI.bodyMass, {
        limit: 0,
        filter: dateFilter,
      });
      const mapped = samples.map((s: any) => ({
        date: new Date(s.startDate),
        value: s.quantity,
      }));
      return pickLatestPerDay(mapped, now);
    }

    case "meditation": {
      const sessions = await HealthKit.queryCategorySamples(
        CTI.mindfulSession,
        { limit: 0, filter: dateFilter },
      );
      return aggregateMeditation(sessions, now);
    }
  }
}
```

- [ ] **Step 4: Add `handleMetricPress` function**

```typescript
async function handleMetricPress(key: MetricKey) {
  setSelectedMetric(key);
  setWeeklyError(null);

  if (weeklyCache[key]) return; // Already cached

  setWeeklyLoading(true);
  try {
    const data = await grabWeeklyData(key);
    setWeeklyCache((prev) => ({ ...prev, [key]: data }));
  } catch (e: any) {
    setWeeklyError(e.message ?? "Failed to load weekly data");
  } finally {
    setWeeklyLoading(false);
  }
}
```

- [ ] **Step 5: Clear weekly cache when grabbing new context**

In `grabContext()`, after `setLoading(true)` and `setError(null)`, add:

```typescript
setWeeklyCache({});
setWeeklyError(null);
```

- [ ] **Step 6: Wire up MetricCard onPress to handleMetricPress**

Update the MetricCard rendering (if not already done in Task 11):

```tsx
onPress={handleMetricPress}
```

- [ ] **Step 7: Commit**

```bash
git add App.tsx
git commit -m "feat: add weekly data fetching with per-metric caching"
```

---

### Task 13: Render MetricDetailSheet

**Files:**
- Modify: `App.tsx`

- [ ] **Step 1: Add MetricDetailSheet rendering**

Just before the closing `</View>` of the root container (before `<View style={styles.buttons}>`... actually, after the entire tree but inside the root `<View style={styles.container}>`), add:

```tsx
{selectedMetric && (
  <MetricDetailSheet
    metricKey={selectedMetric}
    currentValue={
      metrics.find((m) => m.metricKey === selectedMetric)?.value ?? "\u2014"
    }
    currentSublabel={
      metrics.find((m) => m.metricKey === selectedMetric)?.sublabel ?? ""
    }
    data={weeklyCache[selectedMetric] ?? null}
    error={weeklyError}
    onClose={() => {
      setSelectedMetric(null);
      setWeeklyError(null);
    }}
  />
)}
```

Place this after the `</View>` of `styles.buttons` and before the final `</View>` closing `styles.container`.

- [ ] **Step 2: Verify it compiles**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Run all tests**

Run: `npx jest --verbose`
Expected: All tests pass (existing + new weekly tests)

- [ ] **Step 4: Commit**

```bash
git add App.tsx
git commit -m "feat: render MetricDetailSheet on card tap"
```

---

## Chunk 5: Final Verification

### Task 14: Full test suite + type check

- [ ] **Step 1: Run type check**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 2: Run all tests**

Run: `npx jest --verbose`
Expected: All tests pass

- [ ] **Step 3: Review all new/modified files for consistency**

Files to review:
- `lib/weekly.ts` — types, pure functions
- `__tests__/weekly.test.ts` — test coverage
- `components/BarChart.tsx` — bar chart rendering
- `components/LineChart.tsx` — line chart rendering
- `components/MetricDetailSheet.tsx` — sheet with animation
- `App.tsx` — integration, state, HealthKit queries

- [ ] **Step 4: Final commit if any cleanup needed**
