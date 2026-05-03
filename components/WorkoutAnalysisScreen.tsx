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
                    Sets ({result.sets.length})
                  </Text>
                  {result.sets.map((s) => (
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
                          <Text style={styles.setTime}>{fmtLocalHms(s.startDate)}</Text>
                          <Text style={styles.setDuration}>{fmtDuration(s.durationSec)}</Text>
                        </View>
                        <Text style={styles.setDescription}>{s.description}</Text>
                        <View style={styles.setStatsRow}>
                          <Text style={styles.setStat}>peak {s.peakHr}</Text>
                          <Text style={styles.setStat}>avg {s.avgHr}</Text>
                          {s.estimatedReps != null && (
                            <Text style={styles.setStat}>~{s.estimatedReps} reps</Text>
                          )}
                        </View>
                      </View>
                    </View>
                  ))}
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
  setStatsRow: {
    flexDirection: "row",
    gap: 12,
  },
  setStat: {
    color: "#888",
    fontSize: 11,
    fontVariant: ["tabular-nums"],
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
