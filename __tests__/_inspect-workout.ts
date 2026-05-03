import { analyzeWorkout, type HrSample } from "../lib/workoutAnalysis";
import fixture from "./fixtures/heart-rate-2d.json";

const fx = fixture as any;
const w = fx.workouts[0];
const hr: HrSample[] = fx.heartRate.map((s: any) => ({
  startDate: s.startDate,
  bpm: s.bpm,
}));

describe("INSPECT (set INSPECT=1 to print)", () => {
  it("dumps real-fixture analysis when INSPECT env var is set", () => {
    if (!process.env.INSPECT) {
      return;
    }
    const result = analyzeWorkout(
      {
        startDate: w.startDate,
        endDate: w.endDate,
        workoutType: w.workoutType,
        workoutTypeName: "Functional Strength Training",
        totalEnergyKcal: w.totalEnergyKcal,
        source: w.source,
      },
      hr,
    );
    /* eslint-disable no-console */
    console.log("Threshold:", result.thresholdBpm, "bpm");
    console.log("Peak / avg HR:", result.peakHrBpm, "/", result.avgHrBpm);
    console.log("Samples in window:", result.sampleCount);
    console.log("Set count:", result.sets.length);
    console.log("Narrative:\n  " + result.narrative);
    console.log("");
    console.log("Sets:");
    result.sets.forEach((s) => {
      const t = new Date(s.startDate).toISOString().slice(11, 19);
      const dur = `${s.durationSec}s`.padStart(5);
      const reps = s.estimatedReps != null ? String(s.estimatedReps) : "—";
      console.log(
        `  #${String(s.index).padStart(2)} ${t} ${dur} peak=${s.peakHr} avg=${s.avgHr} reps=${reps} [${s.confidence}] ${s.description}`,
      );
    });
    /* eslint-enable no-console */
    expect(result.sets.length).toBeGreaterThan(0);
  });
});
