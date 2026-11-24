# The day, summed up, to Larry — Design Spec

Igor, 2026-11-24 09:07 (via Larry, Cockpit thread igor2-88g.1620, msg faf3017bc6cd): *"Just Grabber Native, push all
the stats, health, and location data, and habits completion to Larry. We should have it all tracked; it helps me do
the weekly reports."* The shape below was proposed to Larry on that thread (cc-lane-pushstats-shape) and agreed as
proposed (msg 567ab576db57), with two additions: where the night's sleep was measured, and habits named by the strip
itself. The Cockpit side is its bead cockpit-61m. Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

Every day the phone hands Larry one record that sums the day up: the night's sleep, steps, exercise, heart rate,
weight, workouts, where Igor was (by place name), and which habits he did. It goes again whenever the day changes:
a late night of sleep syncing from the Watch, a habit ticked the next morning for yesterday, the iPad's taps arriving
over iCloud. Larry keeps the newest one for each day and writes the weekly report from them.

This is beside the [stats archive](2026-10-19-native-stats-archive-design.md), not instead of it. The archive keeps
every raw sample and every point of the trail forever; this record is the day as the app itself reads it, the same
numbers Today and the export show, so Larry doesn't have to work them out again.

## Goals

- Each of the last seven days (the week Today and the export read) reaches Larry as one record, without Igor
  doing anything. A day is final at noon the next day, long before it leaves the week, so every day is sent in
  its final form; older history is in the archive.
- A day that changes after the fact is sent again, and only then; an unchanged day is never sent twice.
- One record never blanks a whole day because one reading failed: a reading Health couldn't give is left empty and
  the rest still go.
- No coordinates ever leave the phone this way: a place is its name, and a place without a name counts only as time.
- A dropped connection loses nothing: what waits goes when the Cockpit is next reachable.

## Non-goals

- Changing the export Larry gets from *Grab Context*: its JSON is a contract and stays byte for byte as it is.
- Raw samples, routes, or the trail itself (the archive has those).
- A screen of its own. What it did is in the session log; Settings has the switch and a status line.
- Sending from the iPad. Only the iPhone has Health, and the iPhone's strip already includes the iPad's taps.

## What a day's record says

- **The day**: the local date, the time zone, when the record was worked out, and whether the day is *final* (it can
  no longer change: from noon on the next day, once its night's sleep is settled).
- **Sleep**: the night that began on that day (noon to noon, as the Sleep sheet reads it): hours asleep and hours in
  bed kept apart, awake, core, deep and REM hours, bedtime and wake, whether it was a nap, and where it was measured
  (the Watch, the phone, entered by hand, or more than one), because hours in bed over-read when no Watch was worn.
- **Movement and the body**: steps, exercise minutes, active energy, walking distance, average, lowest and highest
  heart rate, resting heart rate, heart rate variability, weight in kilograms, mindful minutes.
- **Workouts**: each one's type, start and end, minutes, energy and distance.
- **Places**: each visit to a named place with its start, end and minutes, the minutes per place for the day, and the
  minutes spent at unnamed places, in transit and with no data.
- **Habits**: every item on the daily strip, by the strip's own names, so a new habit flows without a change on
  Larry's side. A check says whether it was done and what made it count (a tap, a finished Gym Timer workout or Box
  breathing session, or Health); a counter says how many.

Times carry Igor's own offset, as the arrivals Larry already gets do.

## When it goes

- After every grab of Health (opening Today, the app coming to the front), the week's seven days are worked out again and
  each day that changed is queued. Today's record goes at most every fifteen minutes; a past day goes as soon as it
  changes.
- The first time, all seven days go, oldest first.
- Only the newest version of a day waits: a day that changes again before it went replaces what was waiting.
- The Cockpit answering *not yet* (it doesn't take these records yet) or not answering keeps the day waiting, and
  it tries again after half a minute, then longer each time up to ten minutes, and whenever the app comes to the
  front. A day the Cockpit refuses is logged with its reason and not sent again until it changes.

## In Settings

A section, *The day to Larry*, with a switch, **Send the day to Larry**, on by default (Igor: *"we should have it
all tracked"*), and under it the last day sent and when, and how many days wait. On the iPad and the Mac the switch
is greyed and the line says only the iPhone sends. Off, nothing is sent, and what waited is dropped;
on again, the week is checked afresh.

## Explaining itself

Each record queued, sent, refused, dropped or waiting is a `daily_push` line in the session log, with the day and
why. A grab whose day records couldn't be worked out says so with a copyable error naming the day.

## Acceptance criteria

- With the switch on and the Cockpit taking records, opening Today sends each of the last seven days once, oldest
  first; opening it again with nothing changed sends nothing.
- A night of sleep that arrives late changes that day's record, and only that day goes again.
- A habit ticked for yesterday sends yesterday again, with the habit done and *a tap* as what made it count.
- A reading Health refused is empty in the record, and every other reading of that day is still there.
- No record ever holds a latitude, a longitude or a place's circle; an unnamed stay counts only as minutes.
- With the Cockpit out of reach, the days wait and go, oldest first, once it answers; with the switch off nothing goes.
- On the iPad nothing is sent.
