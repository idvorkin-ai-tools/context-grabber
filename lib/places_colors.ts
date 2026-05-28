export const PLACE_COLORS = [
  "#4361ee", "#f72585", "#4cc9f0", "#7209b7", "#3a86a7",
  "#f77f00", "#06d6a0", "#e63946", "#a8dadc", "#fca311",
];

export const UNKNOWN_PLACE_COLOR = "#fca311";
export const TRANSIT_COLOR = "#4cc9f0";
export const NO_DATA_COLOR = "#555";
export const FUTURE_COLOR = "#2a2a40";
export const CURRENT_LOCATION_COLOR = "#4cc9f0";

export const PLACE_N_PATTERN = /^Place \d+$/;

export function isUnnamedPlace(placeId: string): boolean {
  return PLACE_N_PATTERN.test(placeId);
}

/**
 * Build a stable color assignment for a set of known place identifiers.
 * Insertion order of `placeIds` determines color slots, so callers should
 * feed the same source (e.g. daily-breakdown discovery order) every time
 * they want colors to match across surfaces.
 *
 * Returns a Map keyed by the same string ids; unnamed "Place N" ids are
 * skipped (they always render as UNKNOWN_PLACE_COLOR at the call site).
 */
export function assignPlaceColors(placeIds: Iterable<string>): Map<string, string> {
  const map = new Map<string, string>();
  let i = 0;
  for (const id of placeIds) {
    if (isUnnamedPlace(id)) continue;
    if (map.has(id)) continue;
    map.set(id, PLACE_COLORS[i % PLACE_COLORS.length]);
    i++;
  }
  return map;
}
