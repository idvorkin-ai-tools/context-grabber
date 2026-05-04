# Workout Analysis — Design Spec

Implements **Phase 2** of GitHub #34 (Detect workouts + post-process for sets/reps + hand off to Larry). Phase 1 (workout list in the Exercise tile) is already shipped. This spec covers the auto-analysis screen that infers set/rep structure from the heart rate signal and shows it back to the user.

## Summary

Tapping a workout in the Exercise sheet opens a Workout Analysis screen that auto-infers what happened during the session — sets, rest periods, rep estimates, and a plain-language narrative — using only the heart rate trace and workout boundaries already in HealthKit. No manual logging required. The output is also what gets handed off to Larry as structured JSON in the daily summary.

## Goals

- Make today's workouts inspectable at a glance: open the app, tap Exercise, tap a workout, see what happened — within two taps from the dashboard.
- Replace manual rep-logging entirely for the user's most common training (kettlebell circuits, get-ups, presses, snatches).
- Produce structured `workouts[]` entries in the daily JSON dump that Larry can reason over (set count, per-set duration, per-set peak/avg HR, rep estimate).
- Show the user the heuristic's reasoning visually — the HR trace with set/rest bands overlaid — so an obviously-wrong inference is obvious before it reaches Larry.

## Non-goals

- Manual logging UI as a fallback inside the app.
- Movement classification (KB swing vs press vs snatch). That's Larry's job downstream — this spec stops at "set N: 35 sec, peak 152, ~10 reps."
- Real-time analysis during the workout. This is a post-hoc reflection screen; the workout has already ended.
- Editing the inferred sets. The user can correct via Larry; this spec is read-only display + JSON export.
- Historical workouts beyond today. Today-only is the v1 scope; older workouts can come later if useful.

## User flow

1. User opens the app, sees the dashboard.
2. User taps the **Exercise** tile.
3. Exercise detail sheet opens (existing behavior). Today's workouts are listed at the top: each row shows workout type, duration, peak HR, source.
4. User taps one of the workout rows.
5. **Workout Analysis screen** opens as a full-page sheet over the Exercise sheet.
6. The screen renders in three regions, top to bottom:
   - **Header**: workout type, start time, duration, peak HR, total active kcal, source, location-if-known.
   - **HR timeline chart**: the raw heart rate trace for the workout window, with translucent green bands marking inferred working sets and gaps marking rest periods. The set boundaries are visually obvious.
   - **Set list**: one row per inferred set, in chronological order. Each row shows set number, start time, duration, peak HR, avg HR, and rep estimate.
7. Above the set list, a one-paragraph **narrative summary** explains what the heuristic thinks happened in plain language ("12 working sets over 47 min. Sets averaged 35 sec at peak HR 148. Pattern looks like a circuit: 3 rounds of 4 movements with ~90s between rounds.").
8. Footer has two actions:
   - **Share JSON** — exports the analyzed workout as a JSON blob (single workout, not the 2-day raw dump from #34 phase 0).
   - **Done** — dismisses back to the Exercise sheet.

## Auto-analysis behavior

The user does not configure anything. Tapping the workout triggers analysis automatically; the screen shows a brief loading state if the HR query takes more than ~500ms, then renders the result.

### Set detection

A "working set" is a contiguous block of elevated heart rate bounded by rest periods.

- **Elevated** = HR ≥ `max(110 bpm, 65% of workout's peak HR)`. The peak-relative threshold adapts to the user's actual exertion in this session.
- **Rest** = HR below the threshold for at least 15 seconds continuously. Sub-15-second dips inside an otherwise-elevated block do not split a set — they're noise from sample timing.
- **Minimum set duration** = 15 seconds. Anything shorter is treated as noise and folded into the surrounding rest.
- **Maximum gap inside a set** = 30 seconds without an HR sample (HealthKit sometimes sparse-samples). Larger gaps split the set.

### Per-set output

Each inferred set produces:

- Sequence number (1-indexed).
- Start time (local time, HH:MM:SS).
- **Time since workout start** — `+M:SS` from set 1's start (or workout start). Lets the user see at a glance how far into the session each set landed.
- **Rest gap before this set** — wall-clock from previous set's *end* to this set's start, formatted `M:SS rest`. Null for set #1. Surfaces the workout shape: short ~30s rests inside a block vs long ~5min rests between blocks become visually obvious.
- Duration in seconds.
- Peak HR during the set.
- Average HR during the set.
- Recovery floor and recovery time (lowest HR after the set + seconds from peak to that floor).
- Rep estimate. The estimate uses a coarse mapping from set duration to rep count for the user's common movement patterns; see "Rep estimation" below. The estimate is allowed to be wrong — the goal is set-level structure for Larry, not authoritative rep counts.

### Rep estimation

Coarse heuristic, deliberately simple:

- Set duration < 20 sec: noise, drop the set.
- 20–45 sec: ballistic block, ~10 reps (KB swings, snatches).
- 45–90 sec: get-up territory, ~3–5 reps (TGU per side, slow grinds).
- 90 sec – 5 min: grinding/circuit block, no specific rep count — surface as "~N min sustained" instead of reps.
- > 5 min: not really a set; treat as a continuous block, no rep count.

These thresholds are tunable and will need iteration against real fixtures (the `__tests__/fixtures/heart-rate-2d.json` dump committed for this project gives us one real workout to start with).

### Narrative summary

A single paragraph generated locally from the set list — no LLM call. It states:

- Total set count and total workout duration.
- Average set duration and average peak HR.
- Whether the spacing looks circuit-like (consistent inter-set rest, similar set durations) or interval-like (variable rest), and how many "rounds" it looks like if circuit-like.
- Whether the HR trace shows a clear warm-up ramp at the start.

Examples:

> "12 working sets over 47 min. Sets averaged 35 sec at peak HR 148. Pattern looks like a circuit: 3 rounds of 4 movements with ~90s rest between rounds. HR ramped from 95 to 130 over the first 3 min — looks like a warm-up block before the first heavy set."

> "1 long sustained block of 8 min at HR 135 + 4 short sets averaging 25 sec at peak HR 162. Looks like a single grinding piece followed by ballistic finishers."

## Acceptance criteria

- Cold-open the app the day after a Kettlebility class → tap Exercise → see the class workout listed → tap it → analysis screen renders within ~1s with HR chart, set bands, and a non-empty set list.
- The set count for a typical 45-min Kettlebility session is in the 12–30 range (not 1 giant block, not 200 micro-blobs). Eyeball test against the real fixture is the bar.
- The HR chart's set/rest bands visually align with the rep estimates in the list — tapping set #5 in the list scrolls/highlights set #5 in the chart (or at minimum the chart band labels match the list numbering).
- Share JSON produces a JSON object matching the Phase 2 shape from issue #34 (workout metadata + `sets[]` array with per-set start/duration/peak/avg/rep estimate).
- The daily JSON dump (existing share button on the main screen) gains a `workouts[]` entry per workout that day, each with the same per-set breakdown — Larry can consume it without the user opening the analysis screen.
- An obviously-wrong inference (single 47-min "set" or 200 noise blobs) is visually distinguishable from a sensible one. The user can decide whether to share the JSON to Larry or not.
- Works for any HealthKit workout source — Apple Watch native, Kettlebility's app, manual entry — as long as HR samples exist in the workout window.
- A workout with no HR samples (manual entry, watch dead) renders the header but the set section says "No heart rate data — set inference unavailable." It does not error or block.

## Edge cases

- **Sparse HR sampling.** If samples are >30 sec apart, set boundaries split there. The chart should visually indicate the gap rather than interpolating across it.
- **All-elevated trace.** If HR never drops below the threshold for ≥15 sec, the entire workout collapses to a single set. Surface this honestly ("1 sustained block, X min at avg HR Y") rather than forcing a split.
- **Threshold collapses.** If `max(110, 65% of peak)` is below baseline (very low-intensity workout), the heuristic produces too many sets. Detect this case and fall back to "low-intensity session, set inference not meaningful."
- **Workout straddles midnight.** Today-only listing means a workout that started yesterday but ended today should still appear under today. Use end-time, not start-time, for the today filter.
- **Multiple overlapping workouts.** If two HK sources logged the same session (Watch + third-party app), prefer the source with more HR samples and silently drop the duplicate.

## Decisions

- **Analysis runs at view time.** Computed when the Workout Analysis screen opens, not at grab time. Memoized in-session so re-opening the same workout is instant. Lets us iterate the heuristic without invalidating cached results.
- **No per-user tuning in v1.** The hardcoded thresholds and rep mapping target Igor's training patterns. The heuristic lives in a single isolated module so swapping later is a one-file change. UX dials in based on real use; thresholds get tuned against fixture + live feedback before we expose any user-facing settings.
- **Per-set confidence dot ships in v1.** Each set row gets a small colored dot (green / yellow / red) indicating how cleanly the set boundary fell — a sharp HR rise + sharp drop on either side scores green, a fuzzy/sparse-sample boundary scores yellow, anything inside a sub-threshold "did this even happen" zone scores red. Helps the user (and Larry) weight the inference at a glance.

## Related

- GitHub #34 — Parent issue (workout detection + post-processing + Larry handoff).
- The 2-day raw HR fixture committed in `a70697e` is the seed test data for tuning the heuristic offline before wiring the in-app screen.
