# Mac Catalyst Support — Design Spec

## Summary

Context Grabber is built and signed for Mac Catalyst (see the 2026-05-23 handoff doc + `patches/react-native-audio-api+*.patch` + `patches/expo-live-activity+*.patch`). The app launches as a windowed Mac app, the React tree mounts, and the dashboard chrome renders. But HealthKit doesn't exist on Mac, so the first thing the app does on launch — `HealthKit.requestAuthorization` — throws "Health data is unavailable on this device," which fills the whole screen with an error banner and aborts the rest of the snapshot pipeline. Nothing else (location, counter, journal, share) is reachable.

This spec defines the user-visible behavior of Context Grabber on Mac Catalyst: which features work, which silently no-op, and how the app degrades when an iOS-only capability is invoked.

## Problem

The iPhone build assumes HealthKit, ActivityKit, App Group container access, and a few other iOS-only APIs are present. On Catalyst they aren't. Today the app blocks on the first missing capability and the user sees a wall of red error text on launch — no dashboard, no controls, no way to copy the error politely, no way to do anything else the Mac *can* do (note-taking, location, share).

## Goals

- Catalyst app launches and renders the dashboard, even when iOS-only data sources are unavailable.
- HealthKit-related metrics show "Not available on Mac" (or are hidden) rather than crashing the snapshot build.
- Features that don't depend on iOS-only APIs continue to work on Mac: tap counter, journal viewer/exporter, manual share, location (Mac has CoreLocation), CloudKit ping.
- Any iOS-only feature invoked on Mac silently no-ops; no error banner.
- Errors that DO surface (e.g. an unexpected location failure) use the standard `<CopyableError>` and don't take over the whole screen — the rest of the dashboard remains usable.

## Non-Goals

- Feature parity with iPhone. Health, widgets, Live Activities, and background location are not expected to work on Mac in v1.
- A separate, hand-tuned macOS UI. The iOS layout reflows onto the Mac window as-is; we accept "iPad-on-Mac" aesthetics.
- App Store submission. This is Igor's personal Mac build.

## User-Visible Behavior

### Launch on Mac

1. Mac user opens Context Grabber from `Applications` (or DerivedData).
2. A standard window appears with the "Context Grabber" header, gear/info buttons, and the same dashboard layout the iPhone shows.
3. The dashboard renders the metric grid, location card, summary banner, and share buttons.
4. Health-derived cards (Steps, Heart Rate, Sleep, Active Energy, Walking Distance, Weight, HRV, Resting Heart Rate, Exercise Minutes, Meditation) display an inline "Not available on Mac" placeholder where the value would be.
5. The tap counter, journal sections, and CloudKit/About panels look and behave exactly as on iPhone.

### Refresh ("Grab Context") on Mac

- The user can pull-to-refresh or tap whatever the refresh affordance is.
- Health data is skipped silently; the snapshot is built with `health` set to a documented "unavailable" marker.
- Location is attempted normally. If it succeeds, the location card and history populate. If it fails, the failure is shown via `<CopyableError>` *inline on the location card*, not as a full-screen banner.
- Counter, journal, etc. continue to function unchanged.

### Share on Mac

- Pressing Share opens the macOS share sheet (the Catalyst-translated version of the iOS share sheet) with the JSON payload.
- The payload's `health` section is either omitted or marked as `"unavailable on this platform"` so the downstream AI coach knows why it's missing — it should not look like "Igor walked 0 steps today."

### iOS-only features the user might tap

- "Start Live Activity" / journal sync to Watch / widget refresh: silently no-op on Mac (no toast, no error, no spinner). If the user explicitly asks "why didn't this do anything," a future iteration can add a "Not available on Mac" inline note, but v1 just no-ops.

## Acceptance Criteria

- [ ] Launching the Catalyst Release `.app` produces a window with the full dashboard chrome (header, gear button, info button, metric grid layout, location section, share buttons).
- [ ] No full-screen error banner appears on launch.
- [ ] HealthKit-derived metric cards visibly indicate "Not available on Mac" (or are hidden) without breaking layout.
- [ ] The tap counter increments and persists across relaunches.
- [ ] Journal entries view loads (if any exist) and exporting them works.
- [ ] CloudKit ping in the About panel works on Mac and round-trips a record.
- [ ] Location grab on Mac either succeeds and renders, or fails into an inline `<CopyableError>` that doesn't hide the rest of the dashboard.
- [ ] No code path reachable from the dashboard throws an unhandled exception that takes over the screen.

## Rationale

The handoff doc is right that "a standalone SwiftUI Mac app talking to the same CloudKit container is dramatically less fragile." But the build is already compiling, signing, and launching — the remaining ~80% of "make Catalyst usable" is just teaching the JS layer that HealthKit isn't there. Going graceful-degradation lets Igor use the Mac build today for the things Catalyst CAN do (journal, counter, share, CloudKit), without committing to a parallel SwiftUI codebase.
