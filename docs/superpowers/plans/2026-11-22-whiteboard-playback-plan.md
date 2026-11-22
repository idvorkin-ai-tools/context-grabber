# Plan: playing a board back, as Notability does

Bead context-grabber-3tdv (from #1139: *"where is my replay button so I can rewatch it the way you do in Notability?"*).
Spec: `2026-11-01-whiteboard-design.md`, *Playing a board back, as Notability does*; stories 958 (the ink) and 959
(what was said). Docs only so far: nothing is built until Igor picks.

## Research

Notability, from its own help article (support.gingerlabs.com, *Recording and Playing Audio*): toolbar record button
with an input meter and timer; *Play* enters playback; hand tool plus a tap on a word, sketch or photo seeks the audio
to that moment; drag to scrub, ±10 s, speeds 0.7×/1×/1.25×/1.5×/2×; ink added during playback is synced too; a
recordings list per note with trim, split, merge, delete; a new recording advised after an hour (recordings may be cut
into one-hour pieces); PDF export can zip the audio in. Third-party guides (conflicting, older): *Note Replay* animates
or highlights the ink written at the playing moment; time-stamped transcripts on paid plans (since 14.4, October
2023), tap a paragraph to see that moment's handwriting. Recording is paid (Plus and up). Notability's sync is its own
cloud now, not iCloud, by the 2026 reviews. No source gave a size per hour: the figures below are our arithmetic.

## What the board already has

| Data | Where it lives today | Good enough for |
|---|---|---|
| `PKStroke.path.creationDate` per stroke | the drawing file, synced through iCloud with the board | stroke order and the gaps between strokes |
| `PKStrokePoint.timeOffset` per point | the same | drawing each stroke at the hand's pace (the scratch-out and hold rules already read it from real Pencil strokes) |
| Kept texts: one shared creation time per text (story 817); paste and snapped shapes: `creationDate: made` | the same | they appear as a unit, at the time they were made |
| Erased, scratched-out, undone ink | nowhere | nothing: playback shows what is left |
| Dictation: BugKit's `NoteDictation` gives text with `firstStart`/`lastEnd` seconds from the start of listening; `mic_on` / `mic_off` log lines have the wall time | words go to the Cockpit with the next picture; not kept on the device (spec: "Words aren't kept for later", #824) | option 2, once kept |
| Sound | nowhere: SFSpeechRecognizer consumes the buffers | option 3 needs a capture |
| `board_touch` paths (story 1104) | the session log, thinned to 600 points | not for playback: logs rotate, and it is diagnostics |

## Options

| | 1. Ink alone | 2. And the words | 3. And the sound |
|---|---|---|---|
| What Igor gets | the board redrawn in order at his pace; tap a stroke to jump | plus captions of what he said as he drew; tap a stroke to read it | Notability's feature: hear the room as the ink draws; tap a stroke to hear it |
| New data | none | per board: lines of `{text, startMs, endMs}` in unix ms, kept in the board's meaning file | per board: one AAC file per recording, plus its start time and length in the meaning |
| Size (our arithmetic) | 0 | at about 150 spoken words a minute and its timing, about 1–2 KB a minute of speech, under 100 KB an hour | AAC mono speech at 32 kbit/s is 4 KB/s, about 14 MB an hour; at 64 kbit/s about 29 MB an hour |
| Privacy | unchanged | his own words kept on the board; changes the spec's "Words aren't kept for later"; the words are dictation's guesses | the room's audio kept, other people's voices included; recording others can need their consent; iOS's orange mic dot shows while it runs |
| iCloud | nothing new | rides the board's meaning sync, which is itself still proposed (cc75 step 2, story 1109); without it the words stay on the drawing device | a CKAsset per recording counts against Igor's iCloud storage and uploads tens of MB over cellular; device-only loses it on a reinstall and the iPhone can't play it |
| Mic rules | none | inherits the board mic's: Ghosts on only, stopped by a call and a shake report | its own button, independent of Ghosts; still stopped by a call (the call owns the mic and its voice processing) and by a shake report |
| Dependencies | none | a BugKit-free change: the board keeps the final results it already receives | BugKit: `NoteDictation` owns the engine and its tap; the audio must be written from that same tap (one input feeds recognition and the file), so this is a bug-kit change first, then a bump here. Recording without the mic open (Ghosts off) needs its own engine or a BugKit mode that records without recognizing |
| Effort | a timeline in ContextCore (host-tested), a playback layer on the canvas, the bar | plus keeping and syncing the lines | plus the bug-kit change, the recorder, the recordings list, deletion, the CloudKit asset |

## Shape of the build (once picked)

1. **Timeline (ContextCore, host tests).** From the strokes' creation times and point offsets: a sorted list of
   (start, duration, stroke) with long gaps compressed (say any gap over 2 s plays as 0.5 s), strokes sharing a time
   grouped. Seek(t) gives the strokes complete and the one part-drawn. A fixture from a real iPad board.
2. **Playback layer (App).** A non-interactive canvas over the board showing `PKDrawing(strokes: done + partial)`,
   the partial stroke a prefix of its path; the real canvas hidden and untouched so nothing saves and no undo step is
   made; the bar (play, pause, ±10 s, scrub, speed). A tap goes to the nearest stroke (the marks' nearest-mark rule)
   and seeks to its start. Session-log events `playback_start`, `playback_seek`, `playback_end` with counts.
3. **Words (option 2).** The board's model keeps each final dictation result with its wall time (mic_on time plus
   `firstStart`), appended to the meaning; the bar shows the line whose span holds the playhead. The spec's "Words
   aren't kept" line and the log's "never the words" stay true for the log and the Cockpit.
4. **Sound (option 3).** bug-kit: `NoteDictation` gains an optional writer on its tap (AAC, mono, 32 kbit/s) and a
   record-only mode; here, a record button, one file per recording beside the board's drawing, its start in the
   meaning, playback driving an `AVAudioPlayer` with the ink following its clock, and (if chosen) a CKAsset on the
   board's record.

## Verification

Docs only now: `just native-test` (lint and the story-ID check). Once built: the timeline on the host; the bar and a
tap-to-seek on the iPad simulator (a UI test drawing three strokes); the Pencil's real pace, the sound and iCloud only
on the iPad and the iPhone.

## Igor's decision

1. Ink alone now? (Recommended: yes, it needs nothing from him and works on every board already drawn.)
2. Then the words or the sound?
3. If the sound: on the device, or through iCloud?
