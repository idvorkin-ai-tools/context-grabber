# Map: real GPS route instead of place-to-place lines — design spec

> **Status:** Drafted 2026-05-31. Changes the today's-path overlay on `StylizedMap` (shipped in #44, per issue #42 "overlay today's path"). The Today and Places maps currently connect visited-place **centroids** with straight segments; this replaces that with the **actual GPS breadcrumb trail**.

---

## Summary

Today's path on the map is drawn as straight lines between the centroids of the places you stayed at — so every segment is a literal "as-the-crow-flies" line *between* two locations. Replace it with the **real route**: the actual GPS breadcrumbs you logged today, in order, so the line follows where you actually went.

## Problem

The path overlay connects stay centroids (one point per place), in time order. The result is a star/triangle of straight lines hopping between your home, work, gym, etc. — lines that don't correspond to any real path and read as visual noise ("why is there a line cutting across the city?"). The information the line implies (a route) isn't the information it shows (place adjacency).

## Goals

- The map's path overlay follows the **actual recorded GPS track** for today, not straight place-to-place segments.
- It stays **smooth and performant** even when today has many breadcrumbs (the trail is thinned so the line doesn't lag the map).
- The place **pins**, the **"You" pin**, and the map controls are unchanged — only the line's shape changes.

## Non-goals

- **No road-snapping.** The line follows the raw GPS points; it does not call a routing/map-matching service to snap to roads. (Straight hops between sparse points are the GPS reality, not synthetic centroid links.)
- **No change to clustering, place detection, or the daily breakdown.** Those still use stays/centroids; only the map line's source changes.
- **No new data collection.** Uses the breadcrumbs already stored.
- **No change to the find-me / fullscreen / copy controls or the pins.**

---

## User-visible behavior

- The today's-path line on the **Today** map and the **Places** map follows the **actual GPS trail** logged today, in chronological order.
- When today has a dense trail, the line is **thinned** (downsampled) to stay smooth — it still traces the real route, just with fewer vertices than every raw point.
- If there are too few points to form a line (0 or 1 today), **no line** is drawn (same as today).
- Place pins and the "You" pin render exactly as before; the map still frames to include the route.
- Gaps where GPS was suppressed (e.g. a long stationary stretch, or travel with no fixes) appear as a straight segment between the last and next recorded point — that's the real recorded data, not a synthetic place link.

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **Follows the real track:** After a day with a walk/drive between two places, the map line **traces the route taken** (curves, turns) rather than a single straight segment between the two place pins.
- **No cross-map star:** Visiting three places no longer draws a triangle of straight centroid-to-centroid lines.
- **Stays smooth:** On a day with a long, dense trail, panning/zooming the map stays responsive (the line is thinned, not every raw point).
- **Sparse day:** With only one recorded point today, no line is drawn.
- **Pins unchanged:** Known-place pins and the "You" pin appear as before; the map frames to show the whole route.

## Rationale

- **Show the information you imply.** A line between dots reads as "this is the path." Making it the *actual* path removes the lie; the straight centroid links were technically a route the user never took.
- **Thinning over precision.** A map widget doesn't need every breadcrumb to convey the route; thinning keeps it legible and fast while preserving the shape. Road-snapping would be prettier but adds a network dependency and a failure mode for marginal benefit — out of scope.

## Cross-references

- The map widget, pins, controls: `components/StylizedMap.tsx`; map controls spec [2026-05-31-map-controls-design.md](2026-05-31-map-controls-design.md).
- Today's-path overlay origin: issue #42 / PR #44.
- Clustering / stays (still used for pins + breakdown): [location clustering v2](2026-03-26-location-clustering-v2.md).
