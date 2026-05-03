// Workout analysis heuristic — turns a raw HR trace + workout boundaries
// into an inferred set list, per-set rep estimates, and a plain-language
// narrative. View-time (not grab-time): cheap enough to recompute on every
// open of the analysis screen.
//
// Tunable thresholds live at the top of the file. They target Igor's
// kettlebell training patterns (ballistics ~30s, TGUs/grinds ~45-90s,
// circuit work in 90s-5min blocks). Per the v1 spec there is no per-user
// configuration — the entire heuristic is one swap when that changes.

// ─── Tunable thresholds ──────────────────────────────────────────────────────

/** Absolute floor for "elevated" HR. Below this, you're not working. */
const ABS_THRESHOLD_BPM = 110;

/** Peak-relative floor: a set must be at >= this fraction of peak HR.
 *  Adapts the threshold to the actual session intensity (a low-key recovery
 *  session has a lower bar than a max-effort circuit). */
const PEAK_FRACTION = 0.65;

/** A working set must sustain elevated HR for at least this many seconds.
 *  Sub-15s blips are noise from sample timing, not real work. */
const MIN_SET_SEC = 15;

/** Rest = sub-threshold for at least this long. Shorter dips inside an
 *  otherwise-elevated block do not split a set. */
const MIN_REST_SEC = 15;

/** Largest gap (no HR sample) tolerated inside a single set. HealthKit
 *  sparse-samples sometimes; > 30s of silence splits the set. */
const MAX_INTRA_SET_GAP_SEC = 30;

/** Below this peak-derived threshold, the heuristic is unreliable — surface
 *  honestly instead of forcing arbitrary set splits. */
const LOW_INTENSITY_PEAK_BPM = 100;

// ─── Types ────────────────────────────────────────────────────────────────────

export type HrSample = {
  /** ISO 8601 timestamp. */
  startDate: string;
  /** Beats per minute at this sample. */
  bpm: number;
};

export type WorkoutMeta = {
  /** ISO 8601 workout start. */
  startDate: string;
  /** ISO 8601 workout end. */
  endDate: string;
  /** Apple HealthKit activity type id (e.g. 50 = Functional Strength). */
  workoutType?: number;
  /** Display string for the activity type. */
  workoutTypeName?: string;
  /** Total active calories for the workout, if known. */
  totalEnergyKcal?: number | null;
  /** Source app/device that logged the workout. */
  source?: string;
};

export type AnalyzedSet = {
  /** 1-indexed sequence number within the workout. */
  index: number;
  /** ISO 8601 start of the set. */
  startDate: string;
  /** ISO 8601 end of the set. */
  endDate: string;
  /** Duration of the set in seconds. */
  durationSec: number;
  /** Peak HR observed in the set. */
  peakHr: number;
  /** Average HR across the set's samples. */
  avgHr: number;
  /** Number of samples that fell inside the set window. */
  sampleCount: number;
  /** Rep count estimate (null when set is too long for a rep mapping). */
  estimatedReps: number | null;
  /** Human-friendly description of the set's character. */
  description: string;
  /** Confidence in the set boundary: green = sharp on/off, yellow = fuzzy
   *  edges or sparse samples, red = barely-elevated or marginal. */
  confidence: "green" | "yellow" | "red";
};

export type AnalyzedWorkout = {
  /** Activity / source / time / kcal pulled through from input meta. */
  meta: WorkoutMeta;
  /** Inferred sets in chronological order. Empty if HR data is unusable. */
  sets: AnalyzedSet[];
  /** Plain-language summary of the workout structure. */
  narrative: string;
  /** Threshold actually used for set detection (bpm). */
  thresholdBpm: number;
  /** Workout's peak HR across all samples. */
  peakHrBpm: number;
  /** Average HR across all in-window samples. */
  avgHrBpm: number;
  /** Total HR samples that fell inside the workout window. */
  sampleCount: number;
  /** When the heuristic considers the result unreliable, this carries a
   *  user-facing explanation. The screen should surface it instead of the
   *  set list. */
  warning: string | null;
};

// ─── Internal helpers ────────────────────────────────────────────────────────

function toMs(iso: string): number {
  return new Date(iso).getTime();
}

function fmtHms(iso: string): string {
  const d = new Date(iso);
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  const ss = String(d.getSeconds()).padStart(2, "0");
  return `${hh}:${mm}:${ss}`;
}

function classifyDuration(durationSec: number): {
  reps: number | null;
  description: string;
} {
  if (durationSec < 20) {
    return { reps: null, description: "Brief blip — likely noise" };
  }
  if (durationSec <= 45) {
    return { reps: 10, description: "Ballistic block (~10 reps)" };
  }
  if (durationSec <= 90) {
    return { reps: 4, description: "Grind/TGU block (~3–5 reps)" };
  }
  if (durationSec <= 5 * 60) {
    const min = Math.round(durationSec / 60);
    return { reps: null, description: `Sustained block (~${min} min)` };
  }
  const min = Math.round(durationSec / 60);
  return { reps: null, description: `Continuous block (~${min} min)` };
}

function scoreConfidence(
  set: { startMs: number; endMs: number; samples: HrSample[]; peakHr: number },
  threshold: number,
  prevEndMs: number | null,
  nextStartMs: number | null,
): "green" | "yellow" | "red" {
  // Marginal sets: barely above threshold, little headroom.
  if (set.peakHr - threshold < 10) return "red";
  // Sparse sampling: < 1 sample per 6 seconds inside the set window.
  const setSec = (set.endMs - set.startMs) / 1000;
  const samplesPerSec = set.samples.length / Math.max(setSec, 1);
  if (samplesPerSec < 1 / 6) return "yellow";
  // Fuzzy edges: rest period before/after is barely the minimum.
  const restBeforeSec = prevEndMs != null ? (set.startMs - prevEndMs) / 1000 : Infinity;
  const restAfterSec = nextStartMs != null ? (nextStartMs - set.endMs) / 1000 : Infinity;
  if (restBeforeSec < MIN_REST_SEC * 1.5 && restAfterSec < MIN_REST_SEC * 1.5) {
    return "yellow";
  }
  return "green";
}

// ─── Set detection ───────────────────────────────────────────────────────────

type RawSet = {
  startMs: number;
  endMs: number;
  samples: HrSample[];
};

/** Walk the sorted in-window samples and bucket them into elevated runs.
 *  Sub-threshold dips < MIN_REST_SEC are absorbed into the surrounding set;
 *  silence gaps > MAX_INTRA_SET_GAP_SEC always split. */
function detectRawSets(
  samples: HrSample[],
  threshold: number,
): RawSet[] {
  const sets: RawSet[] = [];
  let current: RawSet | null = null;
  let lastSampleMs: number | null = null;
  let pendingRestStartMs: number | null = null;

  const closeCurrent = () => {
    if (current) {
      sets.push(current);
      current = null;
    }
    pendingRestStartMs = null;
  };

  for (const s of samples) {
    const ms = toMs(s.startDate);
    const elevated = s.bpm >= threshold;

    // Forced split on long sample silence.
    if (
      current &&
      lastSampleMs != null &&
      (ms - lastSampleMs) / 1000 > MAX_INTRA_SET_GAP_SEC
    ) {
      closeCurrent();
    }

    if (elevated) {
      if (!current) {
        current = { startMs: ms, endMs: ms, samples: [s] };
      } else {
        current.endMs = ms;
        current.samples.push(s);
      }
      pendingRestStartMs = null;
    } else if (current) {
      // Track how long we've been sub-threshold; close set if it crosses
      // the rest minimum.
      if (pendingRestStartMs == null) pendingRestStartMs = ms;
      const restSec = (ms - pendingRestStartMs) / 1000;
      if (restSec >= MIN_REST_SEC) {
        closeCurrent();
      }
    }
    lastSampleMs = ms;
  }
  closeCurrent();

  return sets.filter((s) => (s.endMs - s.startMs) / 1000 >= MIN_SET_SEC);
}

// ─── Narrative ───────────────────────────────────────────────────────────────

function buildNarrative(
  sets: AnalyzedSet[],
  workoutDurationSec: number,
  peakHr: number,
  warmupRampSec: number | null,
): string {
  if (sets.length === 0) {
    return "No clear working sets detected — HR stayed mostly below the working threshold.";
  }
  if (sets.length === 1 && sets[0].durationSec >= 4 * 60) {
    return `1 sustained block of ${Math.round(sets[0].durationSec / 60)} min at avg HR ${sets[0].avgHr}. Looks like a single grinding piece rather than a set-rep workout.`;
  }

  const totalMin = Math.round(workoutDurationSec / 60);
  const avgSetSec = Math.round(
    sets.reduce((sum, s) => sum + s.durationSec, 0) / sets.length,
  );
  const avgPeak = Math.round(
    sets.reduce((sum, s) => sum + s.peakHr, 0) / sets.length,
  );

  // Spacing: stdev of inter-set rests. Low stdev → circuit-like.
  const rests: number[] = [];
  for (let i = 1; i < sets.length; i++) {
    const restSec = (toMs(sets[i].startDate) - toMs(sets[i - 1].endDate)) / 1000;
    rests.push(restSec);
  }
  const restMean = rests.length > 0
    ? rests.reduce((a, b) => a + b, 0) / rests.length
    : 0;
  const restStdev = rests.length > 0
    ? Math.sqrt(
        rests.reduce((sum, r) => sum + (r - restMean) ** 2, 0) / rests.length,
      )
    : 0;

  // If rests are tight (low stdev relative to mean), look for round structure.
  let structureLine = "";
  if (rests.length >= 3 && restStdev / Math.max(restMean, 1) < 0.4) {
    // Tight spacing → likely a circuit. Rounds = sets / movements-per-round,
    // estimate movements-per-round from the longest cluster of similar rests.
    const longRests = rests.filter((r) => r > restMean * 1.5);
    const rounds = longRests.length + 1;
    if (rounds >= 2) {
      const perRound = Math.round(sets.length / rounds);
      structureLine = ` Pattern looks like a circuit: ${rounds} rounds of ~${perRound} movements with consistent spacing between sets.`;
    } else {
      structureLine = " Inter-set spacing is consistent — looks circuit-like.";
    }
  } else if (rests.length > 0) {
    structureLine = " Variable inter-set spacing — looks more like an interval/freestyle session than a circuit.";
  }

  const warmupLine =
    warmupRampSec != null && warmupRampSec >= 60
      ? ` HR ramped over the first ${Math.round(warmupRampSec / 60)} min — looks like a warm-up before the first heavy block.`
      : "";

  return `${sets.length} working sets over ${totalMin} min. Sets averaged ${avgSetSec} sec at peak HR ${avgPeak} (workout peak ${peakHr}).${structureLine}${warmupLine}`;
}

/** First N seconds of monotonically rising HR — rough warm-up indicator. */
function detectWarmupRamp(samples: HrSample[]): number | null {
  if (samples.length < 3) return null;
  const firstMs = toMs(samples[0].startDate);
  let lastMs = firstMs;
  let lastBpm = samples[0].bpm;
  for (const s of samples) {
    const ms = toMs(s.startDate);
    const bpm = s.bpm;
    // Allow brief downticks; require overall trend to be up.
    if (bpm < lastBpm - 5) break;
    lastMs = ms;
    lastBpm = bpm;
    if ((ms - firstMs) / 1000 > 10 * 60) break; // cap at 10 min
  }
  const rampSec = (lastMs - firstMs) / 1000;
  return rampSec >= 30 ? rampSec : null;
}

// ─── Public API ──────────────────────────────────────────────────────────────

/** Run the full analysis on a workout's HR trace. Pure function: same input
 *  in → same output out. */
export function analyzeWorkout(
  meta: WorkoutMeta,
  allHrSamples: HrSample[],
): AnalyzedWorkout {
  const startMs = toMs(meta.startDate);
  const endMs = toMs(meta.endDate);
  const inWindow = allHrSamples
    .filter((s) => {
      const ms = toMs(s.startDate);
      return ms >= startMs && ms <= endMs;
    })
    .sort((a, b) => toMs(a.startDate) - toMs(b.startDate));

  if (inWindow.length === 0) {
    return {
      meta,
      sets: [],
      narrative: "No heart rate samples in the workout window — set inference unavailable.",
      thresholdBpm: ABS_THRESHOLD_BPM,
      peakHrBpm: 0,
      avgHrBpm: 0,
      sampleCount: 0,
      warning: "No heart rate data — set inference unavailable.",
    };
  }

  const peakHr = Math.max(...inWindow.map((s) => s.bpm));
  const avgHr =
    inWindow.reduce((sum, s) => sum + s.bpm, 0) / inWindow.length;
  const threshold = Math.max(
    ABS_THRESHOLD_BPM,
    Math.round(peakHr * PEAK_FRACTION),
  );

  // Low-intensity guard.
  if (peakHr < LOW_INTENSITY_PEAK_BPM) {
    return {
      meta,
      sets: [],
      narrative: `Low-intensity session — peak HR was only ${peakHr}. Set inference is not meaningful below ${LOW_INTENSITY_PEAK_BPM} bpm.`,
      thresholdBpm: threshold,
      peakHrBpm: peakHr,
      avgHrBpm: Math.round(avgHr),
      sampleCount: inWindow.length,
      warning: "Low-intensity session — set inference not meaningful.",
    };
  }

  const rawSets = detectRawSets(inWindow, threshold);

  // All-elevated trace: one giant set spanning the full window.
  if (
    rawSets.length === 1 &&
    (rawSets[0].endMs - rawSets[0].startMs) / 1000 >
      ((endMs - startMs) / 1000) * 0.85
  ) {
    const only = rawSets[0];
    const onlySamples = only.samples;
    const onlyAvg = Math.round(
      onlySamples.reduce((sum, s) => sum + s.bpm, 0) / Math.max(onlySamples.length, 1),
    );
    const set: AnalyzedSet = {
      index: 1,
      startDate: new Date(only.startMs).toISOString(),
      endDate: new Date(only.endMs).toISOString(),
      durationSec: Math.round((only.endMs - only.startMs) / 1000),
      peakHr: Math.max(...onlySamples.map((s) => s.bpm)),
      avgHr: onlyAvg,
      sampleCount: onlySamples.length,
      estimatedReps: null,
      description: classifyDuration((only.endMs - only.startMs) / 1000).description,
      confidence: "yellow",
    };
    return {
      meta,
      sets: [set],
      narrative: `1 sustained block of ${Math.round(set.durationSec / 60)} min at avg HR ${set.avgHr}. HR never dropped below threshold for the full workout — looks like a continuous piece.`,
      thresholdBpm: threshold,
      peakHrBpm: peakHr,
      avgHrBpm: Math.round(avgHr),
      sampleCount: inWindow.length,
      warning: null,
    };
  }

  const sets: AnalyzedSet[] = rawSets.map((raw, i) => {
    const samples = raw.samples;
    const setPeak = Math.max(...samples.map((s) => s.bpm));
    const setAvg = Math.round(
      samples.reduce((sum, s) => sum + s.bpm, 0) / Math.max(samples.length, 1),
    );
    const durationSec = Math.round((raw.endMs - raw.startMs) / 1000);
    const { reps, description } = classifyDuration(durationSec);
    const prevEndMs = i > 0 ? rawSets[i - 1].endMs : null;
    const nextStartMs = i < rawSets.length - 1 ? rawSets[i + 1].startMs : null;
    const confidence = scoreConfidence(
      { ...raw, peakHr: setPeak },
      threshold,
      prevEndMs,
      nextStartMs,
    );
    return {
      index: i + 1,
      startDate: new Date(raw.startMs).toISOString(),
      endDate: new Date(raw.endMs).toISOString(),
      durationSec,
      peakHr: setPeak,
      avgHr: setAvg,
      sampleCount: samples.length,
      estimatedReps: reps,
      description,
      confidence,
    };
  });

  const warmupRampSec = detectWarmupRamp(inWindow);
  const workoutDurationSec = (endMs - startMs) / 1000;

  return {
    meta,
    sets,
    narrative: buildNarrative(sets, workoutDurationSec, peakHr, warmupRampSec),
    thresholdBpm: threshold,
    peakHrBpm: peakHr,
    avgHrBpm: Math.round(avgHr),
    sampleCount: inWindow.length,
    warning: null,
  };
}

// Re-export helpers the UI / share layer will want.
export { fmtHms };
