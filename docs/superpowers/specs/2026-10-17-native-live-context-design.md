# Live context to Larry: arrivals at known places — Design Spec

Issue [#84](https://github.com/idvorkin/context-grabber/issues/84). Igor, 2026-08-29: *"I'd love Context Grabber to
give you live context … that I went to the gym or what my current location is so it can nudge me. And then it could
give me notifications."* He chose, 2026-10-17, to start with arrivals at known places and leave notifications for
after. Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

When Igor arrives at or leaves a known place (Home, Work, the gym), the phone tells Larry, through the Cockpit,
within a few minutes, without Igor opening the app. Larry treats it as he treats a note Igor sent.

## Goals

- An arrival or a departure reaches Larry within five minutes of it happening, with the place's name and the time.
- It works with the app in the background, as long as location recording is on.
- Nothing is sent for places that are not known places: no raw positions leave the phone this way.

## Non-goals (later)

- Workouts starting and ending, battery, signal.
- Larry nudging the phone back (a notification from Larry) — the second half of #84, after this.

## What Igor sees

Nothing new by default: this runs on its own once location recording is on. In Settings, a switch, *Tell Larry
when I arrive and leave*, on by default, and under it the last thing sent (*Arrived at Kettlebility · 6:58*). With
recording off, or no known places, nothing is sent and the line says why.

An arrival counts once Igor has stayed inside a known place for five minutes; a departure once he has been outside
it for five minutes. Passing through does not count. A dropped connection holds the event and sends it when the
Cockpit is next reachable, with the time it happened.

## Explaining itself

- Each arrival and departure is logged (`live_context`, with the place, arrived / left, and sent / waiting /
  failed with the Cockpit's answer).

## Acceptance criteria

- Walking into the gym with the app in the background: Larry has *arrived at the gym* within five minutes.
- Walking past a known place without stopping sends nothing.
- With the switch off, nothing is sent.

## Depends on

The Cockpit accepting these events (`POST /context` on the tailnet), Larry's side of #84 (igor2 bead igor2-88g.263).
