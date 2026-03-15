import { extractSleepDetails } from "../lib/sleep";
import type { SleepSample } from "../lib/health";

describe("extractSleepDetails", () => {
  it("extracts bedtime and wakeTime from a single sample", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result.wakeTime).toBe("2026-03-15T07:00:00.000Z");
  });

  it("extracts bedtime and wakeTime from multiple samples", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T02:00:00.000Z",
      },
      {
        startDate: "2026-03-15T03:00:00.000Z",
        endDate: "2026-03-15T07:30:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result.wakeTime).toBe("2026-03-15T07:30:00.000Z");
  });

  it("returns null/null for empty array", () => {
    const result = extractSleepDetails([]);
    expect(result.bedtime).toBeNull();
    expect(result.wakeTime).toBeNull();
  });

  it("returns null/null for undefined input", () => {
    const result = extractSleepDetails(undefined);
    expect(result.bedtime).toBeNull();
    expect(result.wakeTime).toBeNull();
  });

  it("handles unsorted input and still returns correct values", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-15T03:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T22:00:00.000Z",
        endDate: "2026-03-15T01:00:00.000Z",
      },
      {
        startDate: "2026-03-15T01:30:00.000Z",
        endDate: "2026-03-15T02:30:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    // After sorting: 22:00, 01:30, 03:00
    expect(result.bedtime).toBe("2026-03-14T22:00:00.000Z");
    // Last sample after sorting ends at 07:00
    expect(result.wakeTime).toBe("2026-03-15T07:00:00.000Z");
  });

  it("returns ISO 8601 UTC strings", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date("2026-03-14T23:15:00.000Z"),
        endDate: new Date("2026-03-15T06:45:00.000Z"),
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z$/);
    expect(result.wakeTime).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z$/);
  });
});
