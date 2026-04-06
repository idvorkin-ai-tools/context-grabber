/**
 * Per-day places breakdown from clustering output.
 * Pure functions — no device access, fully testable.
 */

import type { Stay } from "./clustering_v2";
import { formatDateKey } from "./weekly";

export type PlaceVisitDetail = {
  placeId: string;
  startTime: number;  // unix ms
  endTime: number;    // unix ms
  durationMinutes: number;
};

export type PlaceDaySummary = {
  dateKey: string; // "YYYY-MM-DD"
  places: {
    placeId: string; // "Home", "Cafe Turko", "Place 3", etc.
    totalMinutes: number;
  }[]; // sorted by totalMinutes descending, top 10 only
  visits: PlaceVisitDetail[]; // individual visits sorted by startTime
  totalTrackedMinutes: number;
};

/**
 * Build a per-day summary of place visits from clustering stays.
 * Groups stays by local date, sums duration per place, returns top 10 per day.
 */
export function buildPlacesDailySummary(
  stays: Stay[],
  days: number,
): PlaceDaySummary[] {
  if (stays.length === 0) return [];

  // Group stays by local date
  const byDate = new Map<string, { placeMap: Map<string, number>; visits: PlaceVisitDetail[] }>();

  for (const stay of stays) {
    const dateKey = formatDateKey(new Date(stay.startTime));
    if (!byDate.has(dateKey)) byDate.set(dateKey, { placeMap: new Map(), visits: [] });
    const day = byDate.get(dateKey)!;
    day.placeMap.set(stay.placeId, (day.placeMap.get(stay.placeId) ?? 0) + stay.durationMinutes);
    day.visits.push({
      placeId: stay.placeId,
      startTime: stay.startTime,
      endTime: stay.endTime,
      durationMinutes: stay.durationMinutes,
    });
  }

  // Build summaries
  const summaries: PlaceDaySummary[] = [];
  for (const [dateKey, { placeMap, visits }] of byDate) {
    const places = [...placeMap.entries()]
      .map(([placeId, totalMinutes]) => ({ placeId, totalMinutes }))
      .sort((a, b) => b.totalMinutes - a.totalMinutes)
      .slice(0, 10);

    const totalTrackedMinutes = places.reduce((sum, p) => sum + p.totalMinutes, 0);
    visits.sort((a, b) => a.startTime - b.startTime);
    summaries.push({ dateKey, places, visits, totalTrackedMinutes });
  }

  // Sort by date descending (most recent first), take top N days
  summaries.sort((a, b) => b.dateKey.localeCompare(a.dateKey));
  return summaries.slice(0, days);
}
