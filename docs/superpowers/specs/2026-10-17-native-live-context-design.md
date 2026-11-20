# Live context to Larry: arrivals at known places — Design Spec

Issue [#84](https://github.com/idvorkin/context-grabber/issues/84). Igor, 2026-08-29: *"I'd love Context Grabber to
give you live context … that I went to the gym or what my current location is so it can nudge me. And then it could
give me notifications."* He chose, 2026-10-17, to start with arrivals at known places and leave notifications for
after, and on 2026-11-20: *"Go: build arrivals and departures now."* Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

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

### What counts as arriving and leaving

- *Inside* a known place means inside its circle on the Places map, the nearest one when two overlap.
- A position the phone itself reports as less precise than 100 metres is ignored: on the real trail such a fix
  (1.4 km off, one evening at home) would otherwise have sent a departure from Home that never happened.
- The phone stops reporting positions while it lies still, so silence counts as staying where the last position
  was: arriving at the gym and then not moving is an arrival five minutes after the first position inside, even
  if no second position comes.
- The time sent is when it happened: the first position inside the place for an arrival, the first one outside it
  for a departure — not the moment the five minutes ran out, and not when the message finally went.
- Going straight from one known place into another (Work to the café next door) is a departure from the first and
  then an arrival at the second, in that order.
- Turning the switch on, or the first start after an update that brings this, sends nothing about where Igor
  already is: the first place the phone settles in is taken as the starting point, and only changes from it are
  sent.
- A departure names the place as it was called when he arrived, even if it was renamed or deleted since.

### Sending

- Each event is sent once. One that cannot be sent (no network, off the tailnet, the Cockpit down or answering with
  a server error) waits and is tried again on the next chance — each time the app is woken by a position, and when
  it comes to the front — oldest first, keeping its own time.
- An event the Cockpit refuses as wrong (an answer saying the request itself is bad) is not retried: it is marked
  failed, with the Cockpit's reason, and the next event goes on.
- An event still waiting after a day is dropped, and the log says so: Larry hearing on Thursday that Igor reached the
  gym on Monday is noise.

## Explaining itself

- Each arrival and departure is logged as a `live_context` event: the place, arrived or left, when it happened,
  and what became of it — detected, sent, waiting (with why: no answer, a server error), failed (with the
  Cockpit's reason, not retried) or dropped (waited over a day). A position ignored for being imprecise is not
  logged one by one; the count goes on the next event.
- Turning the switch on or off is logged, and so is the starting point taken after turning it on.
- From these alone, a phone's session log answers "did the phone see me arrive, and did Larry get it?" without a
  look at the Cockpit.

## Acceptance criteria

- Walking into the gym with the app in the background: Larry has *arrived at the gym* within five minutes.
- Walking past a known place without stopping sends nothing.
- With the switch off, nothing is sent.
- Driving past the gym, or a position the phone itself reports as imprecise, sends nothing.
- With the Cockpit unreachable, the arrival waits, and goes with its original time once the Cockpit answers.
- Turning the switch on at home sends no *arrived at Home*.

## Depends on

The Cockpit accepting these events, Larry's side of #84 (igor2 bead igor2-88g.263). Nothing on the Cockpit takes them
yet (cockpit#63, item 1). The wire shape is the one proposed to Larry on 2026-11-20, modelled on the Inbox's
([#305](https://github.com/idvorkin/context-grabber/issues/305)): one event per request, carrying the event's own id (so a resend counts once), arrived or left, the
place's name and when it happened — never a position. The Cockpit answers ok (or ok, already had it), a refusal with
a reason (not retried), or a server error (retried). Until the Cockpit takes it, events wait and then drop after a
day, as above, and the log shows them waiting.
