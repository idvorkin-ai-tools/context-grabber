// Raw HealthKit dump for offline workout / set-rep heuristic prototyping.
// Pulls heart rate samples + workouts + HRV + resting HR for a recent window
// so an external script (or Larry) can iterate on the set-detection algorithm
// without rebuilding the app each time.

import HealthKit from "@kingstinct/react-native-healthkit";
import type { QuantityTypeIdentifier } from "@kingstinct/react-native-healthkit";

const HR_QTI = "HKQuantityTypeIdentifierHeartRate" as QuantityTypeIdentifier;
const HRV_QTI = "HKQuantityTypeIdentifierHeartRateVariabilitySDNN" as QuantityTypeIdentifier;
const RESTING_HR_QTI = "HKQuantityTypeIdentifierRestingHeartRate" as QuantityTypeIdentifier;
const ACTIVE_ENERGY_QTI = "HKQuantityTypeIdentifierActiveEnergyBurned" as QuantityTypeIdentifier;

export type HeartRateExportSample = {
  startDate: string;
  endDate?: string;
  bpm: number;
  source: string;
};

export type HeartRateExportWorkout = {
  workoutType: number;
  startDate: string;
  endDate: string;
  durationSec: number;
  totalEnergyKcal: number | null;
  totalDistanceMeters: number | null;
  source: string;
};

export type HeartRateExportPayload = {
  generatedAt: string;
  windowStart: string;
  windowEnd: string;
  daysBack: number;
  counts: {
    heartRate: number;
    hrv: number;
    restingHeartRate: number;
    workouts: number;
    activeEnergyBuckets: number;
  };
  heartRate: HeartRateExportSample[];
  hrv: HeartRateExportSample[];
  restingHeartRate: HeartRateExportSample[];
  workouts: HeartRateExportWorkout[];
  // Active energy in 1-minute buckets via raw samples — useful proxy for
  // intensity when HR sampling has gaps.
  activeEnergySamples: Array<{
    startDate: string;
    endDate?: string;
    kcal: number;
    source: string;
  }>;
};

function safeSourceName(s: any): string {
  return (
    s?.sourceRevision?.source?.toJSON?.()?.name
    ?? s?.sourceRevision?.source?.name
    ?? "unknown"
  );
}

function toIso(d: any): string {
  if (!d) return "";
  if (typeof d === "string") return d;
  if (d instanceof Date) return d.toISOString();
  return new Date(d).toISOString();
}

async function querySamples(
  identifier: QuantityTypeIdentifier,
  startDate: Date,
  endDate: Date,
  unit?: string,
): Promise<HeartRateExportSample[]> {
  const opts: any = {
    limit: 0,
    filter: { date: { startDate, endDate } },
  };
  if (unit) opts.unit = unit;
  const samples = await HealthKit.queryQuantitySamples(identifier, opts);
  return samples.map((s: any) => ({
    startDate: toIso(s.startDate),
    endDate: s.endDate ? toIso(s.endDate) : undefined,
    bpm: s.quantity,
    source: safeSourceName(s),
  }));
}

export async function buildHeartRateExportJson(
  daysBack: number = 2,
): Promise<string> {
  const payload = await buildHeartRateExportPayload(daysBack);
  return JSON.stringify(payload, null, 2);
}

export async function buildHeartRateExportPayload(
  daysBack: number = 2,
): Promise<HeartRateExportPayload> {
  const now = new Date();
  const startDate = new Date(now.getTime() - daysBack * 24 * 60 * 60 * 1000);

  // Fan out the queries — each one independently allowed to fail without
  // poisoning the whole export.
  const [hrRes, hrvRes, restingRes, workoutsRes, energyRes] = await Promise.allSettled([
    querySamples(HR_QTI, startDate, now),
    querySamples(HRV_QTI, startDate, now),
    querySamples(RESTING_HR_QTI, startDate, now),
    HealthKit.queryWorkoutSamples({
      limit: 0,
      filter: { date: { startDate, endDate: now } },
    }),
    HealthKit.queryQuantitySamples(ACTIVE_ENERGY_QTI, {
      limit: 0,
      filter: { date: { startDate, endDate: now } },
      unit: "kcal",
    }),
  ]);

  const heartRate = hrRes.status === "fulfilled" ? hrRes.value : [];
  const hrv = hrvRes.status === "fulfilled" ? hrvRes.value : [];
  const restingHeartRate = restingRes.status === "fulfilled" ? restingRes.value : [];

  const workouts: HeartRateExportWorkout[] =
    workoutsRes.status === "fulfilled"
      ? (workoutsRes.value as any[]).map((w: any) => {
          const json = w.toJSON ? w.toJSON() : w;
          return {
            workoutType: json.workoutActivityType,
            startDate: toIso(json.startDate),
            endDate: toIso(json.endDate),
            durationSec: Math.round(json.duration?.quantity ?? 0),
            totalEnergyKcal:
              json.totalEnergyBurned?.quantity != null
                ? Math.round(json.totalEnergyBurned.quantity)
                : null,
            totalDistanceMeters:
              json.totalDistance?.quantity != null
                ? Math.round(json.totalDistance.quantity)
                : null,
            source: safeSourceName(w),
          };
        })
      : [];

  const activeEnergySamples =
    energyRes.status === "fulfilled"
      ? (energyRes.value as any[]).map((s: any) => ({
          startDate: toIso(s.startDate),
          endDate: s.endDate ? toIso(s.endDate) : undefined,
          kcal: s.quantity,
          source: safeSourceName(s),
        }))
      : [];

  return {
    generatedAt: now.toISOString(),
    windowStart: startDate.toISOString(),
    windowEnd: now.toISOString(),
    daysBack,
    counts: {
      heartRate: heartRate.length,
      hrv: hrv.length,
      restingHeartRate: restingHeartRate.length,
      workouts: workouts.length,
      activeEnergyBuckets: activeEnergySamples.length,
    },
    heartRate,
    hrv,
    restingHeartRate,
    workouts,
    activeEnergySamples,
  };
}
