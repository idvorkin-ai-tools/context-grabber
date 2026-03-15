import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  TouchableOpacity,
  Share,
  Platform,
} from "react-native";
import * as Location from "expo-location";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import type { HealthData } from "./lib/health";
import { buildSummary, formatNumber } from "./lib/summary";

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type ContextSnapshot = {
  timestamp: string;
  health: HealthData;
  location: LocationData;
};

const QTI = {
  stepCount: "HKQuantityTypeIdentifierStepCount" as QuantityTypeIdentifier,
  heartRate: "HKQuantityTypeIdentifierHeartRate" as QuantityTypeIdentifier,
  activeEnergy:
    "HKQuantityTypeIdentifierActiveEnergyBurned" as QuantityTypeIdentifier,
  distance:
    "HKQuantityTypeIdentifierDistanceWalkingRunning" as QuantityTypeIdentifier,
};

const CTI = {
  sleep: "HKCategoryTypeIdentifierSleepAnalysis" as CategoryTypeIdentifier,
};

type MetricCardProps = {
  label: string;
  value: string;
  sublabel: string;
  fullWidth?: boolean;
};

function MetricCard({ label, value, sublabel, fullWidth }: MetricCardProps) {
  const isNull = value === "\u2014";
  return (
    <View style={[styles.metricCard, fullWidth && styles.metricCardFull]}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, isNull && styles.metricValueNull]}>
        {value}
      </Text>
      <Text style={styles.metricSublabel}>{sublabel}</Text>
    </View>
  );
}

export default function App() {
  const [snapshot, setSnapshot] = useState<ContextSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function grabHealthData(): Promise<HealthData> {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const dateFilter = {
      date: { startDate: startOfDay, endDate: now },
    };
    const sleepDateFilter = {
      date: { startDate: yesterday, endDate: now },
    };

    const [steps, heartRate, activeEnergy, walkingDistance, sleep] =
      await Promise.allSettled([
        HealthKit.queryStatisticsForQuantity(QTI.stepCount, ["cumulativeSum"], {
          filter: dateFilter,
        }),
        HealthKit.getMostRecentQuantitySample(QTI.heartRate),
        HealthKit.queryStatisticsForQuantity(
          QTI.activeEnergy,
          ["cumulativeSum"],
          { filter: dateFilter }
        ),
        HealthKit.queryStatisticsForQuantity(QTI.distance, ["cumulativeSum"], {
          filter: dateFilter,
        }),
        HealthKit.queryCategorySamples(CTI.sleep, {
          limit: 0,
          filter: sleepDateFilter,
        }),
      ]);

    let sleepHours: number | null = null;
    if (sleep.status === "fulfilled" && sleep.value.length > 0) {
      const totalMs = sleep.value.reduce((acc, sample) => {
        const start = new Date(sample.startDate).getTime();
        const end = new Date(sample.endDate).getTime();
        return acc + (end - start);
      }, 0);
      sleepHours = Math.round((totalMs / (1000 * 60 * 60)) * 10) / 10;
    }

    return {
      steps:
        steps.status === "fulfilled"
          ? Math.round(steps.value.sumQuantity?.quantity ?? 0)
          : null,
      heartRate:
        heartRate.status === "fulfilled" && heartRate.value
          ? Math.round(heartRate.value.quantity)
          : null,
      activeEnergy:
        activeEnergy.status === "fulfilled"
          ? Math.round(activeEnergy.value.sumQuantity?.quantity ?? 0)
          : null,
      walkingDistance:
        walkingDistance.status === "fulfilled"
          ? Math.round(
              (walkingDistance.value.sumQuantity?.quantity ?? 0) * 100
            ) / 100
          : null,
      sleepHours,
    };
  }

  async function grabLocation(): Promise<LocationData> {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== "granted") {
      return null;
    }
    const loc = await Location.getCurrentPositionAsync({});
    return {
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
      timestamp: loc.timestamp,
    };
  }

  async function grabContext() {
    setLoading(true);
    setError(null);
    try {
      await HealthKit.requestAuthorization({
        toRead: [QTI.stepCount, QTI.heartRate, QTI.activeEnergy, QTI.distance, CTI.sleep],
      });

      const [health, location] = await Promise.all([
        grabHealthData(),
        grabLocation(),
      ]);

      const result: ContextSnapshot = {
        timestamp: new Date().toISOString(),
        health,
        location,
      };
      setSnapshot(result);
    } catch (e: any) {
      setError(e.message ?? "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  async function shareSnapshot() {
    if (!snapshot) return;
    const json = JSON.stringify(snapshot, null, 2);
    await Share.share({
      message: json,
      title: "Context Grabber Snapshot",
    });
  }

  const summaryText = snapshot
    ? buildSummary(snapshot.health, 0)
    : "";

  const h = snapshot?.health;

  // Build metric cards data
  const metrics: MetricCardProps[] = snapshot
    ? [
        {
          label: "Steps",
          value: h?.steps != null ? formatNumber(h.steps) : "\u2014",
          sublabel: "today",
        },
        {
          label: "Heart Rate",
          value: h?.heartRate != null ? `${h.heartRate} bpm` : "\u2014",
          sublabel: "latest",
        },
        {
          label: "Sleep",
          value: h?.sleepHours != null ? `${h.sleepHours} hrs` : "\u2014",
          sublabel:
            h?.bedtime && h?.wakeTime
              ? `${h.bedtime} \u2013 ${h.wakeTime}`
              : "last night",
        },
        {
          label: "Active Energy",
          value: h?.activeEnergy != null ? `${formatNumber(h.activeEnergy)} kcal` : "\u2014",
          sublabel: "today",
        },
        {
          label: "Walking Distance",
          value: h?.walkingDistance != null ? `${h.walkingDistance} km` : "\u2014",
          sublabel: "today",
        },
        {
          label: "Weight",
          value: h?.weight != null ? `${h.weight} kg` : "\u2014",
          sublabel: "latest",
        },
        {
          label: "Meditation",
          value: h?.meditationMinutes != null ? `${h.meditationMinutes} min` : "\u2014",
          sublabel: "today",
        },
      ]
    : [];

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <Text style={styles.title}>Context Grabber</Text>
        <Text style={styles.subtitle}>
          Grab your iPhone context for your AI life coach
        </Text>
      </View>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
      >
        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {snapshot && (
          <>
            {summaryText.length > 0 && (
              <View style={styles.summaryBanner}>
                <Text style={styles.summaryText}>{summaryText}</Text>
              </View>
            )}

            <View style={styles.metricGrid}>
              {metrics.map((m, i) => (
                <MetricCard
                  key={m.label}
                  label={m.label}
                  value={m.value}
                  sublabel={m.sublabel}
                  fullWidth={
                    metrics.length % 2 === 1 && i === metrics.length - 1
                  }
                />
              ))}
            </View>

            <View style={styles.locationCard}>
              <Text style={styles.metricLabel}>Location</Text>
              {snapshot.location ? (
                <Text style={styles.metricValue}>
                  {snapshot.location.latitude.toFixed(4)},{" "}
                  {snapshot.location.longitude.toFixed(4)}
                </Text>
              ) : (
                <Text style={[styles.metricValue, styles.metricValueNull]}>
                  Unavailable
                </Text>
              )}
            </View>

            <Text style={styles.timestamp}>{snapshot.timestamp}</Text>
          </>
        )}
      </ScrollView>

      <View style={styles.buttons}>
        <TouchableOpacity
          style={[styles.button, styles.grabButton]}
          onPress={grabContext}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? "Grabbing..." : "Grab Context"}
          </Text>
        </TouchableOpacity>

        {snapshot && (
          <TouchableOpacity
            style={[styles.button, styles.shareButton]}
            onPress={shareSnapshot}
          >
            <Text style={styles.buttonText}>Share JSON</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#1a1a2e",
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  subtitle: {
    fontSize: 14,
    color: "#888",
    marginTop: 4,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  contentInner: {
    paddingBottom: 20,
  },
  summaryBanner: {
    backgroundColor: "#0f3460",
    borderRadius: 10,
    padding: 12,
    marginTop: 12,
  },
  summaryText: {
    color: "#ccc",
    fontSize: 13,
    textAlign: "center",
  },
  metricGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    marginTop: 12,
  },
  metricCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    width: "48%",
    marginBottom: 10,
  },
  metricCardFull: {
    width: "100%",
  },
  metricLabel: {
    fontSize: 13,
    fontWeight: "600",
    color: "#4cc9f0",
    marginBottom: 4,
  },
  metricValue: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  metricValueNull: {
    color: "#555",
  },
  metricSublabel: {
    fontSize: 11,
    color: "#888",
    marginTop: 2,
  },
  locationCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 2,
  },
  timestamp: {
    fontSize: 12,
    color: "#666",
    marginTop: 12,
    textAlign: "right",
  },
  errorBox: {
    backgroundColor: "#3d1f1f",
    borderRadius: 8,
    padding: 12,
    marginTop: 12,
  },
  errorText: {
    color: "#ff6b6b",
    fontSize: 14,
  },
  buttons: {
    paddingHorizontal: 20,
    paddingBottom: Platform.OS === "ios" ? 40 : 20,
    gap: 10,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  grabButton: {
    backgroundColor: "#4361ee",
  },
  shareButton: {
    backgroundColor: "#2d6a4f",
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
});
