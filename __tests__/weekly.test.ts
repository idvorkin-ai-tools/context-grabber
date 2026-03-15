import {
  formatDateKey,
  bucketByDay,
  computeAverage,
  aggregateHeartRate,
  aggregateSleep,
  aggregateMeditation,
  pickLatestPerDay,
  type DailyValue,
  type HeartRateDaily,
  type MetricKey,
} from "../lib/weekly";
import type { SleepSample, MindfulSession } from "../lib/health";

// Helper: make a Date in LOCAL time (month is 0-indexed)
// 2026-03-15 local => new Date(2026, 2, 15)
const D = (y: number, m: number, d: number) => new Date(y, m - 1, d);

// ─── formatDateKey ────────────────────────────────────────────────────────────

describe("formatDateKey", () => {
  it("formats a date as YYYY-MM-DD in local time", () => {
    expect(formatDateKey(D(2026, 3, 15))).toBe("2026-03-15");
  });

  it("zero-pads month and day", () => {
    expect(formatDateKey(D(2026, 1, 5))).toBe("2026-01-05");
  });

  it("handles year boundary correctly", () => {
    expect(formatDateKey(D(2025, 12, 31))).toBe("2025-12-31");
    expect(formatDateKey(D(2026, 1, 1))).toBe("2026-01-01");
  });
});

// ─── bucketByDay ──────────────────────────────────────────────────────────────

type SimpleQuantitySample = { startDate: Date | string; quantity: number };

describe("bucketByDay", () => {
  const endDate = D(2026, 3, 15); // Sunday

  it("returns 7 null days for empty input", () => {
    const result = bucketByDay<SimpleQuantitySample>([], endDate, 7, (samples) =>
      samples.reduce((s, x) => s + x.quantity, 0)
    );
    expect(result).toHaveLength(7);
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("assigns samples to the correct day", () => {
    // One sample on 2026-03-14 (the day before endDate)
    const samples: SimpleQuantitySample[] = [
      { startDate: D(2026, 3, 14), quantity: 42 },
    ];
    const result = bucketByDay(samples, endDate, 7, (s) =>
      s.reduce((acc, x) => acc + x.quantity, 0)
    );
    // result[0] = oldest (2026-03-09), result[6] = endDate (2026-03-15)
    const march14 = result.find((r) => r.date === "2026-03-14");
    expect(march14).toBeDefined();
    expect(march14!.value).toBe(42);
  });

  it("includes the endDate itself as the last bucket", () => {
    const samples: SimpleQuantitySample[] = [
      { startDate: D(2026, 3, 15), quantity: 99 },
    ];
    const result = bucketByDay(samples, endDate, 7, (s) =>
      s.reduce((acc, x) => acc + x.quantity, 0)
    );
    expect(result[6].date).toBe("2026-03-15");
    expect(result[6].value).toBe(99);
  });

  it("ignores samples outside the 7-day window", () => {
    const samples: SimpleQuantitySample[] = [
      { startDate: D(2026, 3, 8), quantity: 10 }, // 8 days ago — outside window
    ];
    const result = bucketByDay(samples, endDate, 7, (s) =>
      s.reduce((acc, x) => acc + x.quantity, 0)
    );
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("produces a null for a day with no samples (gap)", () => {
    // Only sample on 2026-03-13
    const samples: SimpleQuantitySample[] = [
      { startDate: D(2026, 3, 13), quantity: 5 },
    ];
    const result = bucketByDay(samples, endDate, 7, (s) =>
      s.reduce((acc, x) => acc + x.quantity, 0)
    );
    // Days without samples should be null
    const nullDays = result.filter((r) => r.value === null);
    expect(nullDays.length).toBe(6);
  });

  it("aggregates multiple samples falling on the same day", () => {
    const samples: SimpleQuantitySample[] = [
      { startDate: D(2026, 3, 14), quantity: 10 },
      { startDate: D(2026, 3, 14), quantity: 20 },
    ];
    const result = bucketByDay(samples, endDate, 7, (s) =>
      s.reduce((acc, x) => acc + x.quantity, 0)
    );
    const march14 = result.find((r) => r.date === "2026-03-14");
    expect(march14!.value).toBe(30);
  });

  it("returns dates in chronological order (oldest first)", () => {
    const result = bucketByDay<SimpleQuantitySample>([], endDate, 7, () => 0);
    const dates = result.map((r) => r.date);
    expect(dates[0]).toBe("2026-03-09");
    expect(dates[6]).toBe("2026-03-15");
  });
});

// ─── computeAverage ───────────────────────────────────────────────────────────

describe("computeAverage", () => {
  it("returns null for an empty array", () => {
    expect(computeAverage([])).toBeNull();
  });

  it("returns null when all values are null", () => {
    const values: DailyValue[] = [
      { date: "2026-03-09", value: null },
      { date: "2026-03-10", value: null },
    ];
    expect(computeAverage(values)).toBeNull();
  });

  it("ignores null values in the average", () => {
    const values: DailyValue[] = [
      { date: "2026-03-09", value: null },
      { date: "2026-03-10", value: 10 },
      { date: "2026-03-11", value: 20 },
    ];
    expect(computeAverage(values)).toBe(15);
  });

  it("rounds to 1 decimal place", () => {
    // 10 + 10 + 11 = 31, / 3 = 10.333... → 10.3
    const values: DailyValue[] = [
      { date: "2026-03-09", value: 10 },
      { date: "2026-03-10", value: 10 },
      { date: "2026-03-11", value: 11 },
    ];
    expect(computeAverage(values)).toBe(10.3);
  });

  it("handles a single non-null value", () => {
    const values: DailyValue[] = [{ date: "2026-03-15", value: 7.5 }];
    expect(computeAverage(values)).toBe(7.5);
  });
});

// ─── aggregateHeartRate ───────────────────────────────────────────────────────

type HRSample = { startDate: Date | string; quantity: number };

describe("aggregateHeartRate", () => {
  const endDate = D(2026, 3, 15);

  it("returns 7 days all null when no samples", () => {
    const result = aggregateHeartRate([], endDate);
    expect(result).toHaveLength(7);
    expect(result.every((r) => r.avg === null && r.min === null && r.max === null)).toBe(true);
  });

  it("computes avg/min/max for a day with multiple readings", () => {
    const samples: HRSample[] = [
      { startDate: D(2026, 3, 15), quantity: 60 },
      { startDate: D(2026, 3, 15), quantity: 80 },
      { startDate: D(2026, 3, 15), quantity: 100 },
    ];
    const result = aggregateHeartRate(samples, endDate);
    const today = result.find((r) => r.date === "2026-03-15")!;
    expect(today.avg).toBe(80);
    expect(today.min).toBe(60);
    expect(today.max).toBe(100);
  });

  it("returns null avg/min/max for days with no samples", () => {
    const samples: HRSample[] = [
      { startDate: D(2026, 3, 15), quantity: 72 },
    ];
    const result = aggregateHeartRate(samples, endDate);
    const march14 = result.find((r) => r.date === "2026-03-14")!;
    expect(march14.avg).toBeNull();
    expect(march14.min).toBeNull();
    expect(march14.max).toBeNull();
  });

  it("handles a single reading per day", () => {
    const samples: HRSample[] = [
      { startDate: D(2026, 3, 14), quantity: 65 },
    ];
    const result = aggregateHeartRate(samples, endDate);
    const day = result.find((r) => r.date === "2026-03-14")!;
    expect(day.avg).toBe(65);
    expect(day.min).toBe(65);
    expect(day.max).toBe(65);
  });

  it("rounds avg to 1 decimal place", () => {
    const samples: HRSample[] = [
      { startDate: D(2026, 3, 15), quantity: 60 },
      { startDate: D(2026, 3, 15), quantity: 61 },
      { startDate: D(2026, 3, 15), quantity: 62 },
    ];
    // avg = 183/3 = 61.0
    const result = aggregateHeartRate(samples, endDate);
    const today = result.find((r) => r.date === "2026-03-15")!;
    expect(today.avg).toBe(61);
  });

  it("rounds avg correctly for non-integer result", () => {
    const samples: HRSample[] = [
      { startDate: D(2026, 3, 15), quantity: 70 },
      { startDate: D(2026, 3, 15), quantity: 71 },
    ];
    // avg = 141/2 = 70.5
    const result = aggregateHeartRate(samples, endDate);
    const today = result.find((r) => r.date === "2026-03-15")!;
    expect(today.avg).toBe(70.5);
  });
});

// ─── aggregateSleep ───────────────────────────────────────────────────────────

describe("aggregateSleep", () => {
  const endDate = D(2026, 3, 15);

  it("returns 7 null days when no samples", () => {
    const result = aggregateSleep([], endDate);
    expect(result).toHaveLength(7);
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("assigns sleep to the start date's local day", () => {
    // Sleep starting on 2026-03-14 locally
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 14, 23, 0), // local 2026-03-14 23:00
        endDate: new Date(2026, 2, 15, 7, 0),    // local 2026-03-15 07:00
      },
    ];
    const result = aggregateSleep(samples, endDate);
    const march14 = result.find((r) => r.date === "2026-03-14")!;
    expect(march14.value).toBe(8);
    // March 15 should be null (sleep was assigned to the 14th)
    const march15 = result.find((r) => r.date === "2026-03-15")!;
    expect(march15.value).toBeNull();
  });

  it("merges overlapping samples for the same night", () => {
    // Two overlapping sources for the same night (starts on 2026-03-13)
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 13, 23, 0), // local 2026-03-13 23:00
        endDate: new Date(2026, 2, 14, 7, 0),    // 8 hours
      },
      {
        startDate: new Date(2026, 2, 13, 23, 30), // local 2026-03-13 23:30
        endDate: new Date(2026, 2, 14, 6, 30),    // fully inside first
      },
    ];
    const result = aggregateSleep(samples, endDate);
    const march13 = result.find((r) => r.date === "2026-03-13")!;
    expect(march13.value).toBe(8); // not 15
  });

  it("gaps appear as null", () => {
    // Only one night out of 7
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 15, 0, 0),
        endDate: new Date(2026, 2, 15, 8, 0),
      },
    ];
    const result = aggregateSleep(samples, endDate);
    const nullDays = result.filter((r) => r.value === null);
    expect(nullDays.length).toBe(6);
  });
});

// ─── aggregateMeditation ─────────────────────────────────────────────────────

describe("aggregateMeditation", () => {
  const endDate = D(2026, 3, 15);

  it("returns 7 null days when no sessions", () => {
    const result = aggregateMeditation([], endDate);
    expect(result).toHaveLength(7);
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("sums multiple sessions on the same day", () => {
    const sessions: MindfulSession[] = [
      {
        startDate: new Date(2026, 2, 15, 8, 0),
        endDate: new Date(2026, 2, 15, 8, 10), // 10 min
      },
      {
        startDate: new Date(2026, 2, 15, 12, 0),
        endDate: new Date(2026, 2, 15, 12, 20), // 20 min
      },
    ];
    const result = aggregateMeditation(sessions, endDate);
    const march15 = result.find((r) => r.date === "2026-03-15")!;
    expect(march15.value).toBe(30);
  });

  it("clamps negative durations to zero", () => {
    const sessions: MindfulSession[] = [
      {
        startDate: new Date(2026, 2, 15, 8, 10),
        endDate: new Date(2026, 2, 15, 8, 0), // end before start
      },
      {
        startDate: new Date(2026, 2, 15, 9, 0),
        endDate: new Date(2026, 2, 15, 9, 15), // 15 min
      },
    ];
    const result = aggregateMeditation(sessions, endDate);
    const march15 = result.find((r) => r.date === "2026-03-15")!;
    expect(march15.value).toBe(15);
  });

  it("gaps appear as null", () => {
    const sessions: MindfulSession[] = [
      {
        startDate: new Date(2026, 2, 15, 8, 0),
        endDate: new Date(2026, 2, 15, 8, 10),
      },
    ];
    const result = aggregateMeditation(sessions, endDate);
    const nullDays = result.filter((r) => r.value === null);
    expect(nullDays.length).toBe(6);
  });

  it("handles a single session correctly", () => {
    const sessions: MindfulSession[] = [
      {
        startDate: new Date(2026, 2, 12, 7, 0),
        endDate: new Date(2026, 2, 12, 7, 20), // 20 min
      },
    ];
    const result = aggregateMeditation(sessions, endDate);
    const march12 = result.find((r) => r.date === "2026-03-12")!;
    expect(march12.value).toBe(20);
  });
});

// ─── pickLatestPerDay ─────────────────────────────────────────────────────────

type WeightSample = { startDate: Date | string; quantity: number };

describe("pickLatestPerDay", () => {
  const endDate = D(2026, 3, 15);

  it("returns 7 null days when no samples", () => {
    const result = pickLatestPerDay([], endDate);
    expect(result).toHaveLength(7);
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("picks the latest reading when multiple per day", () => {
    const samples: WeightSample[] = [
      { startDate: new Date(2026, 2, 15, 7, 0), quantity: 75.0 },  // earlier
      { startDate: new Date(2026, 2, 15, 20, 0), quantity: 75.4 }, // later
    ];
    const result = pickLatestPerDay(samples, endDate);
    const march15 = result.find((r) => r.date === "2026-03-15")!;
    expect(march15.value).toBe(75.4);
  });

  it("rounds weight to 2 decimal places", () => {
    const samples: WeightSample[] = [
      { startDate: new Date(2026, 2, 15, 8, 0), quantity: 75.123 },
    ];
    const result = pickLatestPerDay(samples, endDate);
    const march15 = result.find((r) => r.date === "2026-03-15")!;
    expect(march15.value).toBe(75.12);
  });

  it("preserves gaps as null", () => {
    const samples: WeightSample[] = [
      { startDate: new Date(2026, 2, 15, 8, 0), quantity: 75.0 },
    ];
    const result = pickLatestPerDay(samples, endDate);
    const nullDays = result.filter((r) => r.value === null);
    expect(nullDays.length).toBe(6);
  });

  it("ignores samples outside the 7-day window", () => {
    const samples: WeightSample[] = [
      { startDate: new Date(2026, 2, 8, 8, 0), quantity: 75.0 }, // 8 days ago
    ];
    const result = pickLatestPerDay(samples, endDate);
    expect(result.every((r) => r.value === null)).toBe(true);
  });

  it("handles one sample per day across multiple days", () => {
    const samples: WeightSample[] = [
      { startDate: new Date(2026, 2, 13, 8, 0), quantity: 74.5 },
      { startDate: new Date(2026, 2, 14, 8, 0), quantity: 75.0 },
      { startDate: new Date(2026, 2, 15, 8, 0), quantity: 75.5 },
    ];
    const result = pickLatestPerDay(samples, endDate);
    expect(result.find((r) => r.date === "2026-03-13")!.value).toBe(74.5);
    expect(result.find((r) => r.date === "2026-03-14")!.value).toBe(75.0);
    expect(result.find((r) => r.date === "2026-03-15")!.value).toBe(75.5);
  });
});
