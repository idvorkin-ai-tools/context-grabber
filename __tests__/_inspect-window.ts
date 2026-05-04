// One-off inspector for the 15-50 min window of the 5/2 workout (Igor's
// "swings + TGUs" report). Shows: (a) what the heuristic detected, and
// (b) the raw HR trace so we can see swing peaks the heuristic may have
// missed.
//
// Run: INSPECT_WINDOW=1 npx jest _inspect-window

import { analyzeWorkout, type HrSample } from "../lib/workoutAnalysis";
import fixture from "./fixtures/heart-rate-2d.json";

const fx = fixture as any;
const w = fx.workouts[0];
const allHr: HrSample[] = fx.heartRate.map((s: any) => ({
  startDate: s.startDate,
  bpm: s.bpm,
}));

const workoutStartMs = new Date(w.startDate).getTime();
// Default window: minute 0 → 50.  Override with WINDOW_START / WINDOW_END
// env vars (in minutes) for ad-hoc slicing.
const windowStartMin = process.env.WINDOW_START ? Number(process.env.WINDOW_START) : 0;
const windowEndMin = process.env.WINDOW_END ? Number(process.env.WINDOW_END) : 50;
const windowStartMs = workoutStartMs + windowStartMin * 60 * 1000;
const windowEndMs = workoutStartMs + windowEndMin * 60 * 1000;

const fmt = (iso: string) => new Date(iso).toISOString().slice(11, 19);
const fmtMs = (ms: number) => new Date(ms).toISOString().slice(11, 19);

describe("INSPECT window", () => {
  it("dumps trace + sets when INSPECT_WINDOW=1", () => {
    if (!process.env.INSPECT_WINDOW) return;

    /* eslint-disable no-console */
    console.log("Workout start (UTC):", new Date(workoutStartMs).toISOString());
    console.log("Window 15-50 min: ", fmtMs(windowStartMs), "→", fmtMs(windowEndMs));
    console.log("");

    // (a) What the heuristic detected in this window:
    const result = analyzeWorkout(
      {
        startDate: w.startDate,
        endDate: w.endDate,
        workoutTypeName: "Functional Strength Training",
      },
      allHr,
    );
    const setsInWindow = result.sets.filter((s) => {
      const ms = new Date(s.startDate).getTime();
      return ms >= windowStartMs && ms <= windowEndMs;
    });
    console.log(`HEURISTIC sets in window (${setsInWindow.length}):`);
    setsInWindow.forEach((s) => {
      const elapsedMin = Math.floor(
        (new Date(s.startDate).getTime() - workoutStartMs) / 60000,
      );
      const elapsedSec = Math.floor(
        ((new Date(s.startDate).getTime() - workoutStartMs) % 60000) / 1000,
      );
      const recovery = s.recoveryFloorHr != null && s.recoverySec != null
        ? `↓${s.recoveryFloorHr} in ${s.recoverySec}s`
        : "—";
      console.log(
        `  #${String(s.index).padStart(2)} t+${String(elapsedMin).padStart(2)}:${String(elapsedSec).padStart(2,"0")} ${String(s.durationSec).padStart(3)}s peak=${s.peakHr} avg=${s.avgHr} reps=${s.estimatedReps ?? "—"} [${s.confidence}] recover=${recovery}`,
      );
    });
    console.log("");

    // (b) Raw HR trace in the window — every sample with bpm.
    const traceSamples = allHr
      .filter((s) => {
        const ms = new Date(s.startDate).getTime();
        return ms >= windowStartMs && ms <= windowEndMs;
      })
      .sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime());

    console.log(`RAW HR samples in window (${traceSamples.length}):`);
    // Print as "time bpm bar" with a simple visual bar (1 char per 5 bpm above 80)
    for (const s of traceSamples) {
      const barLen = Math.max(0, Math.round((s.bpm - 80) / 3));
      const bar = "█".repeat(Math.min(barLen, 60));
      console.log(`  ${fmt(s.startDate)}  ${String(s.bpm).padStart(3)}  ${bar}`);
    }
    console.log("");

    // (c) Find local maxima above 110 — candidate "peaks" the heuristic might have grouped.
    const candidatePeaks: Array<{ time: string; bpm: number }> = [];
    for (let i = 1; i < traceSamples.length - 1; i++) {
      const prev = traceSamples[i - 1];
      const cur = traceSamples[i];
      const next = traceSamples[i + 1];
      if (cur.bpm >= 120 && cur.bpm > prev.bpm && cur.bpm > next.bpm) {
        candidatePeaks.push({ time: fmt(cur.startDate), bpm: cur.bpm });
      }
    }
    console.log(`LOCAL MAXIMA >= 120 bpm (${candidatePeaks.length}):`);
    candidatePeaks.forEach((p) => {
      console.log(`  ${p.time}  ${p.bpm}`);
    });
    /* eslint-enable no-console */

    expect(setsInWindow.length).toBeGreaterThanOrEqual(0);
  });
});
