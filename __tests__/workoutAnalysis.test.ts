import {
  analyzeWorkout,
  type HrSample,
  type WorkoutMeta,
} from "../lib/workoutAnalysis";
import fixture from "./fixtures/heart-rate-2d.json";

type FixtureShape = {
  heartRate: Array<{ startDate: string; bpm: number }>;
  workouts: Array<{
    startDate: string;
    endDate: string;
    workoutType: number;
    totalEnergyKcal: number | null;
    source: string;
  }>;
};

const fx = fixture as FixtureShape;

const allHr: HrSample[] = fx.heartRate.map((s) => ({
  startDate: s.startDate,
  bpm: s.bpm,
}));

describe("analyzeWorkout — synthetic", () => {
  function mkSamples(
    startIso: string,
    points: Array<{ offsetSec: number; bpm: number }>,
  ): HrSample[] {
    const startMs = new Date(startIso).getTime();
    return points.map((p) => ({
      startDate: new Date(startMs + p.offsetSec * 1000).toISOString(),
      bpm: p.bpm,
    }));
  }

  const baseMeta = (durationSec: number): WorkoutMeta => ({
    startDate: "2026-01-01T10:00:00.000Z",
    endDate: new Date(
      new Date("2026-01-01T10:00:00.000Z").getTime() + durationSec * 1000,
    ).toISOString(),
    workoutType: 50,
    workoutTypeName: "Test",
    source: "test",
  });

  it("returns warning when no HR samples in workout window", () => {
    const result = analyzeWorkout(baseMeta(600), []);
    expect(result.sets).toEqual([]);
    expect(result.warning).toMatch(/no heart rate/i);
  });

  it("flags low-intensity sessions instead of forcing splits", () => {
    const samples = mkSamples("2026-01-01T10:00:00.000Z", [
      { offsetSec: 0, bpm: 80 },
      { offsetSec: 30, bpm: 85 },
      { offsetSec: 60, bpm: 90 },
      { offsetSec: 120, bpm: 95 },
    ]);
    const result = analyzeWorkout(baseMeta(180), samples);
    expect(result.sets).toEqual([]);
    expect(result.warning).toMatch(/low-intensity/i);
  });

  it("detects a single peak bounded by rest", () => {
    const samples = mkSamples("2026-01-01T10:00:00.000Z", [
      { offsetSec: 0, bpm: 90 },
      { offsetSec: 5, bpm: 95 },
      // Set: elevated for ~40s climbing then descending
      { offsetSec: 10, bpm: 130 },
      { offsetSec: 15, bpm: 145 },
      { offsetSec: 20, bpm: 152 },
      { offsetSec: 25, bpm: 150 },
      { offsetSec: 30, bpm: 148 },
      { offsetSec: 35, bpm: 145 },
      { offsetSec: 40, bpm: 140 },
      { offsetSec: 45, bpm: 130 },
      // Rest
      { offsetSec: 55, bpm: 100 },
      { offsetSec: 65, bpm: 95 },
      { offsetSec: 80, bpm: 90 },
    ]);
    const result = analyzeWorkout(baseMeta(90), samples);
    expect(result.sets).toHaveLength(1);
    expect(result.sets[0].peakHr).toBe(152);
    expect(result.sets[0].recoveryFloorHr).toBeLessThanOrEqual(100);
    expect(result.sets[0].recoverySec).toBeGreaterThan(0);
  });

  it("flat-elevated trace yields no peaks (steady-state)", () => {
    // 6 min of solid 140 — no peak structure. Peak-detection should
    // surface this honestly rather than fabricating sets.
    const samples: HrSample[] = [];
    for (let s = 0; s <= 360; s += 5) {
      samples.push({
        startDate: new Date(
          new Date("2026-01-01T10:00:00.000Z").getTime() + s * 1000,
        ).toISOString(),
        bpm: 140,
      });
    }
    const result = analyzeWorkout(baseMeta(360), samples);
    expect(result.sets).toHaveLength(0);
    expect(result.narrative).toMatch(/steady-state|prominent/i);
  });

  it("splits two peaks even with shallow recovery (Igor's swing pattern)", () => {
    // Recovery dips only to 122 between sets — the failure mode of the old
    // threshold algorithm (122 > 110 = no rest detected = one giant set).
    // Peak detection should still find both peaks via prominence.
    const samples = mkSamples("2026-01-01T10:00:00.000Z", [
      // Set A peak
      { offsetSec: 0, bpm: 130 },
      { offsetSec: 5, bpm: 145 },
      { offsetSec: 10, bpm: 152 },
      { offsetSec: 15, bpm: 150 },
      { offsetSec: 20, bpm: 145 },
      { offsetSec: 25, bpm: 138 },
      // Shallow recovery — only dips to 122
      { offsetSec: 35, bpm: 128 },
      { offsetSec: 50, bpm: 124 },
      { offsetSec: 65, bpm: 122 },
      // Set B peak
      { offsetSec: 75, bpm: 132 },
      { offsetSec: 80, bpm: 145 },
      { offsetSec: 85, bpm: 152 },
      { offsetSec: 90, bpm: 150 },
      { offsetSec: 95, bpm: 145 },
      { offsetSec: 100, bpm: 138 },
      { offsetSec: 110, bpm: 125 },
      { offsetSec: 125, bpm: 120 },
    ]);
    const result = analyzeWorkout(baseMeta(135), samples);
    expect(result.sets.length).toBe(2);
    expect(result.sets[0].peakHr).toBe(152);
    expect(result.sets[1].peakHr).toBe(152);
    expect(result.sets[0].recoveryFloorHr).toBeLessThanOrEqual(125);
  });
});

describe("analyzeWorkout — real fixture (Kettlebility-style 96-min session)", () => {
  // The fixture has exactly one workout: 2026-05-02 16:22 → 18:23 UTC,
  // type 50 (Functional Strength Training), 666 kcal on Watch Ultra.
  const w = fx.workouts[0];
  const meta: WorkoutMeta = {
    startDate: w.startDate,
    endDate: w.endDate,
    workoutType: w.workoutType,
    workoutTypeName: "Functional Strength Training",
    totalEnergyKcal: w.totalEnergyKcal,
    source: w.source,
  };

  const result = analyzeWorkout(meta, allHr);

  it("loads the fixture", () => {
    expect(fx.heartRate.length).toBeGreaterThan(2000);
    expect(fx.workouts).toHaveLength(1);
  });

  it("produces a non-empty set list with no warning", () => {
    expect(result.warning).toBeNull();
    expect(result.sets.length).toBeGreaterThan(0);
  });

  it("set count is plausible (not 1 giant block, not 200 micro-blobs)", () => {
    // Spec acceptance: typical 45-min Kettlebility session → 12-30 sets.
    // This one is 96 min so allow a wider band; primary bar is "not 1, not >200".
    expect(result.sets.length).toBeGreaterThan(3);
    expect(result.sets.length).toBeLessThan(80);
  });

  it("threshold adapts to the actual peak HR", () => {
    expect(result.thresholdBpm).toBeGreaterThanOrEqual(110);
    // Peak-fraction floor should be in play if peak is above ~170.
    if (result.peakHrBpm >= 170) {
      expect(result.thresholdBpm).toBeGreaterThanOrEqual(
        Math.round(result.peakHrBpm * 0.65) - 1,
      );
    }
  });

  it("every set is well-ordered, peak >= avg, and has a peakAt timestamp", () => {
    for (let i = 0; i < result.sets.length; i++) {
      const s = result.sets[i];
      expect(s.avgHr).toBeLessThanOrEqual(s.peakHr);
      expect(s.index).toBe(i + 1);
      expect(s.peakAt).toBeTruthy();
      expect(new Date(s.peakAt).getTime()).toBeGreaterThanOrEqual(
        new Date(s.startDate).getTime(),
      );
      expect(new Date(s.peakAt).getTime()).toBeLessThanOrEqual(
        new Date(s.endDate).getTime(),
      );
      if (i > 0) {
        const prev = result.sets[i - 1];
        expect(new Date(s.startDate).getTime()).toBeGreaterThanOrEqual(
          new Date(prev.endDate).getTime() - 1000, // tolerate adjacent boundaries
        );
      }
    }
  });

  it("sets have recovery floor + recovery time fields populated", () => {
    // Inner sets always have a following set, so recovery should be defined.
    for (let i = 0; i < result.sets.length - 1; i++) {
      const s = result.sets[i];
      expect(s.recoveryFloorHr).not.toBeNull();
      expect(s.recoverySec).not.toBeNull();
      expect(s.recoveryFloorHr!).toBeLessThanOrEqual(s.peakHr);
    }
  });

  it("narrative mentions the set count and an avg/peak HR figure", () => {
    expect(result.narrative).toMatch(/working set|sustained block/i);
    expect(result.narrative).toMatch(/HR/);
  });

  it("each set has a confidence label in the green/yellow/red set", () => {
    for (const s of result.sets) {
      expect(["green", "yellow", "red"]).toContain(s.confidence);
    }
  });
});
