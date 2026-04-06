import { buildPlacesDailySummary, type PlaceDaySummary } from "../lib/places_summary";
import type { Stay } from "../lib/clustering_v2";

function makeStay(placeId: string, startTime: number, durationMinutes: number): Stay {
  return {
    placeId,
    centroid: { latitude: 47.6, longitude: -122.3 },
    startTime,
    endTime: startTime + durationMinutes * 60 * 1000,
    durationMinutes,
    pointCount: 10,
  };
}

// Helper: local midnight for a given date string (YYYY-MM-DD)
function localMidnight(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 8, 0, 0).getTime(); // 8am local
}

describe("buildPlacesDailySummary", () => {
  test("empty stays returns empty result", () => {
    expect(buildPlacesDailySummary([], 7)).toEqual([]);
  });

  test("single day with multiple places sorted by duration", () => {
    const base = localMidnight("2026-03-15");
    const stays: Stay[] = [
      makeStay("Home", base, 120),
      makeStay("Office", base + 3 * 3600000, 60),
      makeStay("Cafe", base + 5 * 3600000, 180),
    ];

    const result = buildPlacesDailySummary(stays, 7);
    expect(result).toHaveLength(1);
    expect(result[0].dateKey).toBe("2026-03-15");
    // Sorted by duration desc: Cafe (180), Home (120), Office (60)
    expect(result[0].places[0].placeId).toBe("Cafe");
    expect(result[0].places[0].totalMinutes).toBe(180);
    expect(result[0].places[1].placeId).toBe("Home");
    expect(result[0].places[1].totalMinutes).toBe(120);
    expect(result[0].places[2].placeId).toBe("Office");
    expect(result[0].places[2].totalMinutes).toBe(60);
    expect(result[0].totalTrackedMinutes).toBe(360);
  });

  test("multiple days sorted by date descending", () => {
    const stays: Stay[] = [
      makeStay("Home", localMidnight("2026-03-13"), 60),
      makeStay("Home", localMidnight("2026-03-15"), 90),
      makeStay("Home", localMidnight("2026-03-14"), 120),
    ];

    const result = buildPlacesDailySummary(stays, 7);
    expect(result).toHaveLength(3);
    expect(result[0].dateKey).toBe("2026-03-15");
    expect(result[1].dateKey).toBe("2026-03-14");
    expect(result[2].dateKey).toBe("2026-03-13");
  });

  test("respects days limit", () => {
    const stays: Stay[] = [
      makeStay("Home", localMidnight("2026-03-10"), 60),
      makeStay("Home", localMidnight("2026-03-11"), 60),
      makeStay("Home", localMidnight("2026-03-12"), 60),
      makeStay("Home", localMidnight("2026-03-13"), 60),
      makeStay("Home", localMidnight("2026-03-14"), 60),
    ];

    const result = buildPlacesDailySummary(stays, 3);
    expect(result).toHaveLength(3);
    expect(result[0].dateKey).toBe("2026-03-14");
    expect(result[2].dateKey).toBe("2026-03-12");
  });

  test("top 10 places limit enforced", () => {
    const base = localMidnight("2026-03-15");
    const stays: Stay[] = [];
    for (let i = 0; i < 15; i++) {
      stays.push(makeStay(`Place ${i}`, base + i * 600000, (15 - i) * 10));
    }

    const result = buildPlacesDailySummary(stays, 7);
    expect(result).toHaveLength(1);
    expect(result[0].places).toHaveLength(10);
    // First place should have most minutes
    expect(result[0].places[0].totalMinutes).toBeGreaterThanOrEqual(
      result[0].places[9].totalMinutes,
    );
  });

  test("same place across multiple stays on same day gets summed", () => {
    const base = localMidnight("2026-03-15");
    const stays: Stay[] = [
      makeStay("Home", base, 60),
      makeStay("Office", base + 3600000, 30),
      makeStay("Home", base + 7200000, 90),
    ];

    const result = buildPlacesDailySummary(stays, 7);
    expect(result).toHaveLength(1);
    expect(result[0].places[0].placeId).toBe("Home");
    expect(result[0].places[0].totalMinutes).toBe(150); // 60 + 90
    expect(result[0].places[1].placeId).toBe("Office");
    expect(result[0].places[1].totalMinutes).toBe(30);
  });
});
