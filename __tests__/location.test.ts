import { pruneThreshold } from "../lib/location";

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
