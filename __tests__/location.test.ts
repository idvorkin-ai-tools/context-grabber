import { pruneThreshold, buildTodaysRoute } from "../lib/location";

describe("pruneThreshold", () => {
  it("returns correct UTC cutoff for 30 day retention", () => {
    const now = Date.UTC(2026, 2, 15, 12, 0, 0); // 2026-03-15T12:00:00Z
    const threshold = pruneThreshold(30, now);
    const expected = now - 30 * 86400000;
    expect(threshold).toBe(expected);
  });

  it("30 day retention: threshold is exactly 30 * 86400000 ms before now", () => {
    const now = 1773849600000; // some fixed timestamp
    const threshold = pruneThreshold(30, now);
    expect(now - threshold).toBe(30 * 86400000);
  });

  it("0 day retention prunes everything", () => {
    const now = Date.UTC(2026, 2, 15, 12, 0, 0);
    const threshold = pruneThreshold(0, now);
    // threshold equals now, so all timestamps < now are pruned
    expect(threshold).toBe(now);
  });

  it("retention change downward: immediate prune applies", () => {
    const now = Date.UTC(2026, 2, 15, 12, 0, 0);
    // Originally 30 days
    const oldThreshold = pruneThreshold(30, now);
    // Changed to 7 days
    const newThreshold = pruneThreshold(7, now);
    // New threshold is more recent (higher), so more data gets pruned
    expect(newThreshold).toBeGreaterThan(oldThreshold);
    expect(now - newThreshold).toBe(7 * 86400000);
  });

  it("1 day retention", () => {
    const now = Date.UTC(2026, 2, 15, 0, 0, 0);
    const threshold = pruneThreshold(1, now);
    expect(now - threshold).toBe(86400000);
  });
});

describe("buildTodaysRoute", () => {
  // Local-time noon today, derived from a fixed base so tests are deterministic
  // relative to the machine's TZ (buildTodaysRoute uses local midnight).
  const noon = new Date(2026, 4, 31, 12, 0, 0).getTime();
  const HOUR = 3600_000;
  function pt(latOffset: number, msAgo: number) {
    return { latitude: 47.6 + latOffset, longitude: -122.3, timestamp: noon - msAgo };
  }

  it("keeps only today's points, chronological, as {lat,lon,timestamp}", () => {
    const route = buildTodaysRoute(
      [pt(0.02, 1 * HOUR), pt(0.01, 2 * HOUR), pt(0.5, 30 * HOUR)], // last is yesterday
      noon,
    );
    // Yesterday's point dropped; remaining two ordered oldest→newest.
    expect(route.map((p) => p.timestamp)).toEqual([
      noon - 2 * HOUR,
      noon - 1 * HOUR,
    ]);
    expect(route[0].lat).toBeCloseTo(47.61, 6);
    expect(route[1].lat).toBeCloseTo(47.62, 6);
    expect(route[0].lon).toBe(-122.3);
    expect(Object.keys(route[0]).sort()).toEqual(["lat", "lon", "timestamp"]);
  });

  it("drops non-finite coordinates", () => {
    const route = buildTodaysRoute(
      [
        { latitude: NaN, longitude: -122.3, timestamp: noon - HOUR },
        pt(0.01, 2 * HOUR),
      ],
      noon,
    );
    expect(route).toHaveLength(1);
    expect(route[0].lat).toBe(47.61);
  });

  it("excludes future points (after now)", () => {
    const route = buildTodaysRoute([pt(0.01, -HOUR), pt(0.02, HOUR)], noon);
    expect(route).toHaveLength(1);
    expect(route[0].timestamp).toBe(noon - HOUR);
  });

  it("thins to maxPoints, preserving first and last", () => {
    const pts = Array.from({ length: 1000 }, (_, i) => ({
      latitude: 47.6 + i * 0.0001,
      longitude: -122.3,
      timestamp: noon - (1000 - i) * 1000, // ascending, all within today
    }));
    const route = buildTodaysRoute(pts, noon, 100);
    expect(route.length).toBeLessThanOrEqual(100);
    expect(route[0].timestamp).toBe(pts[0].timestamp);
    expect(route[route.length - 1].timestamp).toBe(pts[999].timestamp);
  });

  it("returns a single point unchanged (caller draws no line for <2)", () => {
    const route = buildTodaysRoute([pt(0.01, HOUR)], noon);
    expect(route).toHaveLength(1);
  });

  it("returns empty for no points", () => {
    expect(buildTodaysRoute([], noon)).toEqual([]);
  });
});
