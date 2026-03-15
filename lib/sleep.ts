/**
 * Pure functions for extracting sleep detail metrics from HealthKit sleep samples.
 */

import type { SleepSample } from "./health";

export type SleepDetails = {
  bedtime: string | null;
  wakeTime: string | null;
};

/**
 * Extract bedtime and wake-up time from sleep category samples.
 * Sorts samples by startDate ascending, then:
 *   - bedtime = startDate of first sample (ISO 8601 UTC)
 *   - wakeTime = endDate of last sample (ISO 8601 UTC)
 * Returns { bedtime: null, wakeTime: null } if samples is empty or undefined.
 */
export function extractSleepDetails(
  samples: SleepSample[] | undefined,
): SleepDetails {
  if (!samples || samples.length === 0) {
    return { bedtime: null, wakeTime: null };
  }

  const sorted = [...samples].sort(
    (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
  );

  const bedtime = new Date(sorted[0].startDate).toISOString();
  const wakeTime = new Date(sorted[sorted.length - 1].endDate).toISOString();

  return { bedtime, wakeTime };
}
