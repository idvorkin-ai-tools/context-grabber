/**
 * Pure functions for location tracking logic.
 */

/**
 * Calculate the pruning threshold timestamp.
 * Returns a UTC unix milliseconds timestamp; any location with a timestamp
 * before this value should be pruned.
 *
 * @param retentionDays Number of days to retain. 0 means prune everything.
 * @param now Current time as UTC unix milliseconds.
 * @returns Cutoff timestamp in UTC unix milliseconds.
 */
export function pruneThreshold(retentionDays: number, now: number): number {
  const safeDays = Math.max(0, retentionDays);
  return now - safeDays * 86400000;
}

export type RouteInputPoint = {
  latitude: number;
  longitude: number;
  timestamp: number;
};

export type RoutePathPoint = {
  lat: number;
  lon: number;
  timestamp: number;
};

/**
 * Build today's GPS route for the map overlay: the raw breadcrumbs logged
 * since local midnight (up to `now`), in chronological order, thinned to at
 * most `maxPoints` so the polyline stays smooth. The first and last points
 * are always kept; non-finite coordinates are dropped. Pure — `now` drives
 * the local-day window.
 */
export function buildTodaysRoute(
  points: RouteInputPoint[],
  now: number,
  maxPoints = 400,
): RoutePathPoint[] {
  const dayStart = new Date(now);
  dayStart.setHours(0, 0, 0, 0);
  const startMs = dayStart.getTime();

  const todays = points
    .filter(
      (p) =>
        p.timestamp >= startMs &&
        p.timestamp <= now &&
        Number.isFinite(p.latitude) &&
        Number.isFinite(p.longitude),
    )
    .sort((a, b) => a.timestamp - b.timestamp);

  return thinPoints(todays, maxPoints).map((p) => ({
    lat: p.latitude,
    lon: p.longitude,
    timestamp: p.timestamp,
  }));
}

/**
 * Evenly stride a list down to at most `maxPoints`, always keeping the first
 * and last element so the route's endpoints are preserved.
 */
function thinPoints<T>(points: T[], maxPoints: number): T[] {
  if (maxPoints < 2 || points.length <= maxPoints) return points;
  const stride = (points.length - 1) / (maxPoints - 1);
  const out: T[] = [];
  for (let i = 0; i < maxPoints; i++) {
    out.push(points[Math.round(i * stride)]);
  }
  // De-dup any repeats introduced by rounding near the tail.
  return out.filter((p, i) => i === 0 || p !== out[i - 1]);
}
