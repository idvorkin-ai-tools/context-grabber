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
//
// V2 algorithm: peak detection. Find local maxima with prominence
// (rise from preceding valley AND fall to following valley) above a
// threshold. Robust to high cardio baselines where between-set HR doesn't
// fall back to "rest" — the dip-then-climb shape is what matters.

/** Absolute floor — a peak below this is too weak to count as a real set
 *  (e.g. you walked across the gym). */
const PEAK_MIN_BPM = 115;

/** A peak must rise this many bpm above the preceding valley AND fall this
 *  many bpm to the next valley. This is what catches Igor's swing peaks
 *  even when his between-set recovery only dips to 115-120. */
const MIN_PROMINENCE_BPM = 8;

/** Set window expands outward from the peak until HR drops by this many bpm
 *  (or hits the edge of the workout / next peak). Defines what's "in" the set. */
const SET_DESCENT_BPM = 6;

/** Below this peak HR for the whole workout, the heuristic is unreliable. */
const LOW_INTENSITY_PEAK_BPM = 100;

/** Rolling-window size for HR smoothing (samples). Removes single-sample
 *  noise without smearing real peaks. Use 3 — a moving median across 3
 *  samples (~10-15s) preserves sharp ballistic peaks. */
const SMOOTHING_WINDOW = 3;

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
  /** ISO 8601 timestamp of the peak HR sample. */
  peakAt: string;
  /** Average HR across the set's samples. */
  avgHr: number;
  /** Number of samples that fell inside the set window. */
  sampleCount: number;
  /** Lowest HR reached after this set, before the next set begins (or end of
   *  workout for the last set). null when there's no rest period after. */
  recoveryFloorHr: number | null;
  /** Seconds from peak HR to recovery floor. null when no rest after. */
  recoverySec: number | null;
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
  prominenceBpm: number,
  durationSec: number,
  sampleCount: number,
): "green" | "yellow" | "red" {
  // High prominence + decent sample density → confident set.
  const samplesPerSec = sampleCount / Math.max(durationSec, 1);
  if (prominenceBpm < MIN_PROMINENCE_BPM + 4) return "red";
  if (samplesPerSec < 1 / 6) return "yellow";
  if (prominenceBpm < MIN_PROMINENCE_BPM + 12) return "yellow";
  return "green";
}

// ─── Set detection (peak-prominence algorithm) ───────────────────────────────

type RawSet = {
  /** Inclusive index in the smoothed sample array where the set begins. */
  startIdx: number;
  /** Inclusive index where the set ends. */
  endIdx: number;
  /** Index of the peak sample within the set window. */
  peakIdx: number;
};

/** Median smoothing across a window centered on each sample. Preserves
 *  sharp peaks (median is robust) while removing single-sample noise
 *  spikes. The output array is the same length as the input. */
function smoothMedian(samples: HrSample[], window: number): HrSample[] {
  const half = Math.floor(window / 2);
  const out: HrSample[] = [];
  for (let i = 0; i < samples.length; i++) {
    const lo = Math.max(0, i - half);
    const hi = Math.min(samples.length - 1, i + half);
    const slice: number[] = [];
    for (let j = lo; j <= hi; j++) slice.push(samples[j].bpm);
    slice.sort((a, b) => a - b);
    const med = slice[Math.floor(slice.length / 2)];
    out.push({ startDate: samples[i].startDate, bpm: med });
  }
  return out;
}

/** Find indices of local maxima with prominence ≥ MIN_PROMINENCE_BPM and
 *  peak ≥ PEAK_MIN_BPM. Prominence = min(rise from prev valley, fall to
 *  next valley). */
function findPeaks(samples: HrSample[]): number[] {
  if (samples.length < 3) return [];
  const peaks: number[] = [];
  // First pass: identify all strict local maxima.
  const candidateIdx: number[] = [];
  for (let i = 1; i < samples.length - 1; i++) {
    if (
      samples[i].bpm >= PEAK_MIN_BPM &&
      samples[i].bpm > samples[i - 1].bpm &&
      samples[i].bpm >= samples[i + 1].bpm
    ) {
      candidateIdx.push(i);
    }
  }
  // Second pass: gate by prominence. For each candidate, walk outward to
  // find the lowest point before the next candidate (left valley) and the
  // lowest point before the next candidate (right valley).
  for (let c = 0; c < candidateIdx.length; c++) {
    const i = candidateIdx[c];
    const peakBpm = samples[i].bpm;
    // Left valley: from previous peak (or 0) up to i.
    const leftBound = c > 0 ? candidateIdx[c - 1] : 0;
    let leftMin = peakBpm;
    for (let j = leftBound; j < i; j++) {
      if (samples[j].bpm < leftMin) leftMin = samples[j].bpm;
    }
    // Right valley: from i to next peak (or end).
    const rightBound = c < candidateIdx.length - 1
      ? candidateIdx[c + 1]
      : samples.length - 1;
    let rightMin = peakBpm;
    for (let j = i + 1; j <= rightBound; j++) {
      if (samples[j].bpm < rightMin) rightMin = samples[j].bpm;
    }
    const prominence = Math.min(peakBpm - leftMin, peakBpm - rightMin);
    if (prominence >= MIN_PROMINENCE_BPM) {
      peaks.push(i);
    }
  }
  return peaks;
}

/** Expand outward from each peak to define the set window: walk back until
 *  HR drops by SET_DESCENT_BPM from the peak (or we hit the previous peak's
 *  midpoint), then walk forward similarly. */
function buildSetsFromPeaks(
  samples: HrSample[],
  peaks: number[],
): RawSet[] {
  return peaks.map((peakIdx, k) => {
    const peakBpm = samples[peakIdx].bpm;
    const descentFloor = peakBpm - SET_DESCENT_BPM;
    // Boundary against the previous peak: midpoint between adjacent peaks.
    const leftBound = k > 0
      ? Math.floor((peaks[k - 1] + peakIdx) / 2)
      : 0;
    const rightBound = k < peaks.length - 1
      ? Math.floor((peaks[k + 1] + peakIdx) / 2)
      : samples.length - 1;
    let startIdx = peakIdx;
    while (startIdx > leftBound && samples[startIdx - 1].bpm >= descentFloor) {
      startIdx--;
    }
    let endIdx = peakIdx;
    while (endIdx < rightBound && samples[endIdx + 1].bpm >= descentFloor) {
      endIdx++;
    }
    return { startIdx, endIdx, peakIdx };
  });
}

/** Walk between consecutive sets to find each set's recovery floor (lowest
 *  HR before the next set's window starts) + recovery time (sec from this
 *  set's peak to that floor). The last set has no following set, so its
 *  recovery is computed against the end of the workout window. */
function computeRecoveryMetrics(
  samples: HrSample[],
  sets: RawSet[],
  workoutEndMs: number,
): Array<{ floorHr: number | null; recoverySec: number | null }> {
  return sets.map((set, i) => {
    const restStart = set.endIdx + 1;
    const restEnd = i < sets.length - 1
      ? sets[i + 1].startIdx - 1
      : samples.length - 1;
    if (restEnd < restStart) {
      return { floorHr: null, recoverySec: null };
    }
    let floorHr = samples[restStart].bpm;
    let floorIdx = restStart;
    for (let j = restStart + 1; j <= restEnd; j++) {
      if (samples[j].bpm < floorHr) {
        floorHr = samples[j].bpm;
        floorIdx = j;
      }
    }
    const peakMs = toMs(samples[set.peakIdx].startDate);
    const floorMs = toMs(samples[floorIdx].startDate);
    const recoverySec = Math.max(0, Math.round((floorMs - peakMs) / 1000));
    // Sanity: ignore meaningless 0-sec recoveries (single rest sample at
    // the very next slot).
    if (i === sets.length - 1) {
      const remainingSec = (workoutEndMs - toMs(samples[set.endIdx].startDate)) / 1000;
      if (remainingSec < 10) return { floorHr: null, recoverySec: null };
    }
    return { floorHr, recoverySec };
  });
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
      thresholdBpm: PEAK_MIN_BPM,
      peakHrBpm: 0,
      avgHrBpm: 0,
      sampleCount: 0,
      warning: "No heart rate data — set inference unavailable.",
    };
  }

  const peakHr = Math.max(...inWindow.map((s) => s.bpm));
  const avgHr =
    inWindow.reduce((sum, s) => sum + s.bpm, 0) / inWindow.length;
  // Effective working threshold for the narrative + UI display. Not used
  // by the peak-detection algorithm itself — left in the result type for
  // backward-compat with callers that expect to render it.
  const threshold = Math.max(PEAK_MIN_BPM, Math.round(peakHr * 0.7));

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

  // Smooth, find peaks, build set windows. Only smooth when samples are
  // dense enough that single-sample noise is plausible (≤6s avg interval).
  // Sparse synthetic data shouldn't be smoothed — the median collapses
  // legitimate sharp peaks.
  const totalWindowSec = (endMs - startMs) / 1000;
  const avgIntervalSec = totalWindowSec / inWindow.length;
  const smoothed =
    avgIntervalSec <= 6
      ? smoothMedian(inWindow, SMOOTHING_WINDOW)
      : inWindow;
  const peakIdxs = findPeaks(smoothed);
  const rawSets = buildSetsFromPeaks(smoothed, peakIdxs);
  const recoveries = computeRecoveryMetrics(smoothed, rawSets, endMs);

  if (rawSets.length === 0) {
    return {
      meta,
      sets: [],
      narrative: `Peak HR ${peakHr}, avg ${Math.round(avgHr)}. No prominent set/rest peaks detected — HR pattern looks more like a steady-state piece than discrete sets.`,
      thresholdBpm: threshold,
      peakHrBpm: peakHr,
      avgHrBpm: Math.round(avgHr),
      sampleCount: inWindow.length,
      warning: null,
    };
  }

  const sets: AnalyzedSet[] = rawSets.map((raw, i) => {
    const setSamples = smoothed.slice(raw.startIdx, raw.endIdx + 1);
    const peakSample = smoothed[raw.peakIdx];
    const setStart = smoothed[raw.startIdx];
    const setEnd = smoothed[raw.endIdx];
    const setPeak = peakSample.bpm;
    const setAvg = Math.round(
      setSamples.reduce((sum, s) => sum + s.bpm, 0) / Math.max(setSamples.length, 1),
    );
    const durationSec = Math.round(
      (toMs(setEnd.startDate) - toMs(setStart.startDate)) / 1000,
    );
    const { reps, description } = classifyDuration(durationSec);
    // Prominence: smaller of (peak - left valley) and (peak - right valley).
    const leftBound = i > 0 ? rawSets[i - 1].peakIdx : 0;
    const rightBound = i < rawSets.length - 1 ? rawSets[i + 1].peakIdx : smoothed.length - 1;
    let leftMin = setPeak;
    for (let j = leftBound; j < raw.peakIdx; j++) {
      if (smoothed[j].bpm < leftMin) leftMin = smoothed[j].bpm;
    }
    let rightMin = setPeak;
    for (let j = raw.peakIdx + 1; j <= rightBound; j++) {
      if (smoothed[j].bpm < rightMin) rightMin = smoothed[j].bpm;
    }
    const prominence = Math.min(setPeak - leftMin, setPeak - rightMin);
    const confidence = scoreConfidence(prominence, durationSec, setSamples.length);
    return {
      index: i + 1,
      startDate: setStart.startDate,
      endDate: setEnd.startDate,
      durationSec,
      peakHr: setPeak,
      peakAt: peakSample.startDate,
      avgHr: setAvg,
      sampleCount: setSamples.length,
      recoveryFloorHr: recoveries[i].floorHr,
      recoverySec: recoveries[i].recoverySec,
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
