// Workout Analysis Screen — opens when the user taps a workout row in the
// Exercise detail sheet. Auto-runs the heuristic and shows the inferred
// set/rest structure with confidence dots and a plain-language narrative.
// Spec: docs/superpowers/specs/2026-05-03-workout-analysis-design.md

import React, { useEffect, useMemo, useState } from "react";
import {
  Modal,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import {
  analyzeWorkout,
  type AnalyzedWorkout,
  type HrSample,
  type WorkoutMeta,
} from "../lib/workoutAnalysis";
import type { WorkoutEntry } from "../lib/health";
import RecoverySparkline from "./RecoverySparkline";

type Props = {
  /** The workout to analyze. null hides the modal. */
  workout: WorkoutEntry | null;
  onClose: () => void;
  /** Resolves to raw HR samples within the given window. */
  fetchHrSamples: (startIso: string, endIso: string) => Promise<HrSample[]>;
};

function fmtLocalTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function fmtLocalHms(iso: string): string {
  const d = new Date(iso);
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  const ss = String(d.getSeconds()).padStart(2, "0");
  return `${hh}:${mm}:${ss}`;
}

function fmtDuration(sec: number): string {
  if (sec < 60) return `${sec}s`;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

/** M:SS format (e.g., 5:42 or 0:24). Used for time deltas — distinct from
 *  the duration formatter so consecutive deltas stay visually consistent. */
function fmtMmSs(sec: number): string {
  const total = Math.max(0, Math.round(sec));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

const CONFIDENCE_COLOR = {
  green: "#4ade80",
  yellow: "#fbbf24",
  red: "#ef4444",
} as const;

export default function WorkoutAnalysisScreen({
  workout,
  onClose,
  fetchHrSamples,
}: Props): React.JSX.Element {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<AnalyzedWorkout | null>(null);
  const [error, setError] = useState<string | null>(null);

  const meta: WorkoutMeta | null = useMemo(() => {
    if (!workout || !workout.startTime || !workout.endTime) return null;
    return {
      startDate: workout.startTime,
      endDate: workout.endTime,
      workoutTypeName: workout.activityType,
      totalEnergyKcal: workout.energyBurned,
    };
  }, [workout]);

  useEffect(() => {
    if (!workout || !meta) {
      setResult(null);
      setError(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const hr = await fetchHrSamples(meta.startDate, meta.endDate);
        if (cancelled) return;
        setResult(analyzeWorkout(meta, hr));
      } catch (e: any) {
        if (cancelled) return;
        setError(e?.message ?? "Analysis failed");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [workout, meta, fetchHrSamples]);

  function handleShare() {
    if (!result) return;
    const payload = {
      workout: {
        activityType: result.meta.workoutTypeName,
        startDate: result.meta.startDate,
        endDate: result.meta.endDate,
        durationSec: Math.round(
          (new Date(result.meta.endDate).getTime() -
            new Date(result.meta.startDate).getTime()) /
            1000,
        ),
        totalEnergyKcal: result.meta.totalEnergyKcal ?? null,
        source: result.meta.source ?? null,
        peakHrBpm: result.peakHrBpm,
        avgHrBpm: result.avgHrBpm,
        sampleCount: result.sampleCount,
        thresholdBpm: result.thresholdBpm,
      },
      narrative: result.narrative,
      warning: result.warning,
      sets: result.sets.map((s) => ({
        index: s.index,
        startDate: s.startDate,
        endDate: s.endDate,
        durationSec: s.durationSec,
        peakHr: s.peakHr,
        avgHr: s.avgHr,
        sampleCount: s.sampleCount,
        estimatedReps: s.estimatedReps,
        description: s.description,
        confidence: s.confidence,
      })),
    };
    void Share.share({ message: JSON.stringify(payload, null, 2) });
  }

  const visible = workout != null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Workout Analysis</Text>
          <TouchableOpacity onPress={onClose} style={styles.closeButton}>
            <Text style={styles.closeText}>Done</Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.scrollContent}
        >
          {workout && meta && (
            <View style={styles.metaCard}>
              <Text style={styles.metaTitle}>{workout.activityType}</Text>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Start</Text>
                <Text style={styles.metaValue}>
                  {fmtLocalTime(meta.startDate)} · {new Date(meta.startDate).toLocaleDateString()}
                </Text>
              </View>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Duration</Text>
                <Text style={styles.metaValue}>{workout.durationMinutes} min</Text>
              </View>
              {workout.energyBurned != null && (
                <View style={styles.metaRow}>
                  <Text style={styles.metaLabel}>Energy</Text>
                  <Text style={styles.metaValue}>{workout.energyBurned} kcal</Text>
                </View>
              )}
              {result && (
                <>
                  <View style={styles.metaRow}>
                    <Text style={styles.metaLabel}>Peak HR</Text>
                    <Text style={styles.metaValue}>{result.peakHrBpm} bpm</Text>
                  </View>
                  <View style={styles.metaRow}>
                    <Text style={styles.metaLabel}>Avg HR</Text>
                    <Text style={styles.metaValue}>{result.avgHrBpm} bpm</Text>
                  </View>
                  <View style={styles.metaRow}>
                    <Text style={styles.metaLabel}>Threshold</Text>
                    <Text style={styles.metaValue}>{result.thresholdBpm} bpm</Text>
                  </View>
                </>
              )}
            </View>
          )}

          {workout && (!workout.startTime || !workout.endTime) && (
            <View style={styles.warningCard}>
              <Text style={styles.warningText}>
                This workout has no recorded start/end time — set inference
                requires a precise window.
              </Text>
            </View>
          )}

          {loading && (
            <View style={styles.statusCard}>
              <Text style={styles.statusText}>Analyzing heart rate…</Text>
            </View>
          )}

          {error && (
            <View style={styles.warningCard}>
              <Text style={styles.warningText}>Couldn't analyze: {error}</Text>
            </View>
          )}

          {result && (
            <>
              <View style={styles.narrativeCard}>
                <Text style={styles.narrativeLabel}>What probably happened</Text>
                <Text style={styles.narrativeText}>{result.narrative}</Text>
              </View>

              {result.warning && (
                <View style={styles.warningCard}>
                  <Text style={styles.warningText}>{result.warning}</Text>
                </View>
              )}

              {result.sets.length > 0 && (
                <View style={styles.setsCard}>
                  <Text style={styles.setsLabel}>
                    Sets ({result.sets.length}) · started {fmtLocalHms(result.meta.startDate)}
                  </Text>
                  {result.sets.map((s, i) => {
                    const workoutStartMs = new Date(result.meta.startDate).getTime();
                    const setStartMs = new Date(s.startDate).getTime();
                    const sinceStartSec = (setStartMs - workoutStartMs) / 1000;
                    const prev = i > 0 ? result.sets[i - 1] : null;
                    const restSec = prev
                      ? (setStartMs - new Date(prev.endDate).getTime()) / 1000
                      : null;
                    const paceSec = prev
                      ? (setStartMs - new Date(prev.startDate).getTime()) / 1000
                      : null;
                    const drop =
                      s.recoveryFloorHr != null
                        ? s.peakHr - s.recoveryFloorHr
                        : null;
                    // Find indices into the trace for the peak / floor / set-end
                    // markers so the sparkline can highlight them.
                    const peakAtSec = Math.round(
                      (new Date(s.peakAt).getTime() - setStartMs) / 1000,
                    );
                    const setEndSec = s.durationSec;
                    const peakIdx = s.trace.findIndex((p) => p.tSec >= peakAtSec);
                    const setEndIdx = s.trace.findIndex((p) => p.tSec >= setEndSec);
                    let floorIdx = -1;
                    if (s.recoveryFloorHr != null) {
                      // First trace sample at or below the floor after the peak.
                      for (let k = Math.max(0, peakIdx); k < s.trace.length; k++) {
                        if (s.trace[k].bpm <= s.recoveryFloorHr) {
                          floorIdx = k;
                          break;
                        }
                      }
                    }
                    return (
                      <View key={s.index} style={styles.setRow}>
                        <View
                          style={[
                            styles.confidenceDot,
                            { backgroundColor: CONFIDENCE_COLOR[s.confidence] },
                          ]}
                        />
                        <View style={styles.setBody}>
                          <View style={styles.setHeaderRow}>
                            <Text style={styles.setIndex}>#{s.index}</Text>
                            <Text style={styles.deltaLine}>
                              {i === 0
                                ? "start"
                                : `+${fmtMmSs(sinceStartSec)} · rest ${fmtMmSs(restSec ?? 0)} · pace ${fmtMmSs(paceSec ?? 0)}`}
                            </Text>
                            <Text style={styles.setDuration}>{fmtDuration(s.durationSec)}</Text>
                          </View>
                          <Text style={styles.setDescription}>
                            {s.description}
                            {s.pass === "loose" && (
                              <Text style={styles.looseTag}> · loose</Text>
                            )}
                          </Text>
                          <View style={styles.setStatsRow}>
                            <Text style={styles.setStat}>peak {s.peakHr}</Text>
                            <Text style={styles.setStat}>avg {s.avgHr}</Text>
                            {s.estimatedReps != null && (
                              <Text style={styles.setStat}>~{s.estimatedReps} reps</Text>
                            )}
                          </View>
                          {s.recoveryFloorHr != null && s.recoverySec != null && (
                            <View style={styles.setStatsRow}>
                              <Text style={styles.recoveryStat}>
                                ↓{drop} to {s.recoveryFloorHr} in {s.recoverySec}s
                              </Text>
                            </View>
                          )}
                        </View>
                        {s.trace.length >= 2 && (
                          <RecoverySparkline
                            trace={s.trace}
                            width={120}
                            height={64}
                            peakIdx={peakIdx >= 0 ? peakIdx : undefined}
                            floorIdx={floorIdx >= 0 ? floorIdx : undefined}
                            setEndIdx={setEndIdx >= 0 ? setEndIdx : undefined}
                          />
                        )}
                      </View>
                    );
                  })}
                </View>
              )}

              <TouchableOpacity
                style={styles.shareButton}
                onPress={handleShare}
              >
                <Text style={styles.shareButtonText}>Share JSON</Text>
              </TouchableOpacity>
            </>
          )}
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#111828",
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#333",
  },
  headerTitle: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "600",
  },
  closeButton: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  closeText: {
    color: "#3b82f6",
    fontSize: 16,
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 60,
  },
  metaCard: {
    backgroundColor: "rgba(255,255,255,0.04)",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  metaTitle: {
    color: "#e0e0e0",
    fontSize: 18,
    fontWeight: "600",
    marginBottom: 8,
  },
  metaRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 4,
  },
  metaLabel: {
    color: "#888",
    fontSize: 13,
  },
  metaValue: {
    color: "#e0e0e0",
    fontSize: 13,
    fontVariant: ["tabular-nums"],
  },
  narrativeCard: {
    backgroundColor: "rgba(59,130,246,0.08)",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderLeftWidth: 3,
    borderLeftColor: "#3b82f6",
  },
  narrativeLabel: {
    color: "#888",
    fontSize: 11,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 1,
    marginBottom: 6,
  },
  narrativeText: {
    color: "#e0e0e0",
    fontSize: 14,
    lineHeight: 20,
  },
  setsCard: {
    backgroundColor: "rgba(255,255,255,0.03)",
    borderRadius: 12,
    padding: 12,
    marginBottom: 12,
  },
  setsLabel: {
    color: "#888",
    fontSize: 11,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 1,
    marginLeft: 4,
    marginBottom: 6,
  },
  setRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 4,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "rgba(255,255,255,0.05)",
  },
  confidenceDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginTop: 6,
    marginRight: 12,
  },
  setBody: {
    flex: 1,
  },
  setHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 2,
  },
  setIndex: {
    color: "#e0e0e0",
    fontSize: 14,
    fontWeight: "600",
    width: 32,
  },
  setTime: {
    color: "#888",
    fontSize: 12,
    fontVariant: ["tabular-nums"],
    flex: 1,
  },
  setDuration: {
    color: "#e0e0e0",
    fontSize: 13,
    fontWeight: "600",
    fontVariant: ["tabular-nums"],
  },
  setDescription: {
    color: "#aaa",
    fontSize: 12,
    marginBottom: 2,
  },
  looseTag: {
    color: "#fbbf24",
    fontSize: 11,
    fontStyle: "italic",
  },
  deltaLine: {
    color: "#7a8595",
    fontSize: 11,
    fontStyle: "italic",
    fontVariant: ["tabular-nums"],
    flex: 1,
  },
  setStatsRow: {
    flexDirection: "row",
    gap: 12,
  },
  setStat: {
    color: "#888",
    fontSize: 11,
    fontVariant: ["tabular-nums"],
  },
  recoveryStat: {
    color: "#6b7280",
    fontSize: 11,
    fontStyle: "italic",
    fontVariant: ["tabular-nums"],
    marginTop: 2,
  },
  statusCard: {
    padding: 20,
    alignItems: "center",
  },
  statusText: {
    color: "#888",
    fontSize: 14,
  },
  warningCard: {
    backgroundColor: "rgba(251,191,36,0.08)",
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
    borderLeftWidth: 3,
    borderLeftColor: "#fbbf24",
  },
  warningText: {
    color: "#e0e0e0",
    fontSize: 13,
    lineHeight: 18,
  },
  shareButton: {
    backgroundColor: "rgba(255,255,255,0.06)",
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 4,
  },
  shareButtonText: {
    color: "#e0e0e0",
    fontSize: 15,
    fontWeight: "600",
  },
});
