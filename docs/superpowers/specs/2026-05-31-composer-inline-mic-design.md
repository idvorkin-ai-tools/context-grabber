# Composer: inline mic + continuous record-on-add-another — design spec

> **Status:** Drafted 2026-05-31. Two refinements to the shared entry composer behind the Affirmation and Grateful cards ([Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md)). Builds on the "Save while recording finalizes the clip" behavior already shipped (`c246fd7`).

---

## Summary

1. **Continuous recording across "Save & add another".** If you're recording when you tap **Save & add another**, the clip is saved and a **fresh recording starts automatically** on the new blank entry — so you can rattle off several voice entries without re-tapping the mic each time.
2. **Mic in line with Opportunity / Did It.** On the Affirmation card, the record control becomes a **compact mic button on the same row** as the Opportunity and Did-It buttons, instead of a separate full-width button lower down.

## Problem

- **Logging several voice entries in a row is clunky.** Today, "Save & add another" clears the card but leaves the mic idle — you have to tap Record again for each entry. When you're capturing a burst of reflections by voice, that re-tap breaks the flow.
- **The record button is far from the action.** On the Affirmation card you pick a context (Opportunity / Did-It) and then your eye has to travel down past the text field to find Record. Putting the mic on the same row as the context buttons keeps the "choose how, then speak" controls together.

## Goals

- Tapping **Save & add another** *while recording* saves the current clip and immediately begins recording the next entry.
- On the Affirmation card, **Record sits on the same row** as Opportunity / Did-It as a compact mic button.
- The mic clearly shows recording state (it turns red while recording).
- The shared composer stays shared — the Grateful card keeps working, and the mic can be placed by whichever card hosts it.

## Non-goals

- **No change to plain Save.** Plain **Save** still finalizes any in-progress clip, saves, and closes the card — it does not start a new recording (there's no new entry to record into).
- **No change to the Grateful card's layout.** Grateful has no Opportunity/Did-It row; its record control stays where it is (full-width below the field). Only its Save-&-add-another gains the continuous-recording behavior, same as Affirmation.
- **No change to what gets saved** — same audio file handling, same entry shape, same role tagging.
- **No auto-start on first open.** Opening the card does not begin recording; the change is only about *continuing* a recording streak across Save & add another.

---

## User-visible behavior

### Continuous record on "Save & add another"

- While a recording is in progress, tapping **Save & add another**:
  - finalizes and saves the current clip (today's behavior),
  - clears the card for a new entry (today's behavior),
  - **and immediately starts a new recording** so the mic is already live for the next entry.
- The newly started recording shows the same live recording state (red mic) as a normally-started one.
- If you tap **Save & add another** when **not** recording (e.g. a text entry, or a clip you already stopped), nothing new starts — behavior is unchanged.
- Tapping plain **Save** while recording finalizes and saves the clip and **closes** the card — no new recording (unchanged).

### Mic in line with Opportunity / Did It (Affirmation card)

- The Opportunity and Did-It buttons remain the two primary buttons on their row; a **compact circular mic button sits to their right on the same row**.
- The mic is **idle (neutral)** by default and **turns red while recording**. Tapping it starts/stops recording, exactly like the old Record button.
- The separate full-width Record button no longer appears on the Affirmation card (its job moved to the inline mic).
- After a recording is captured, the existing "voice ready · duration · discard" confirmation still appears so you can review or discard before saving.

---

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **Streak by voice:** On the Affirmation card, tap the inline mic and speak ~3s, then tap **Save & add another**. The entry saves, the card clears, and the mic is **already recording** (red) for the next one. Speak again, tap **Save & add another** again — a second entry saves and recording continues. Tap **Save** to finish; the card closes.
- **No phantom start:** Type a text entry (no recording) and tap **Save & add another**. The entry saves and the card clears, but the mic is **not** recording.
- **Plain save closes:** Start recording, tap **Save** (not add-another). The clip saves and the card closes; the mic is off.
- **Inline mic layout:** On the Affirmation card, Opportunity, Did-It, and the mic are on one row. The mic is neutral until tapped, then red while recording.
- **Mic still captures:** Tap the inline mic, speak, tap it again to stop — the "voice ready · 0:0X" confirmation shows; saving attaches the clip.
- **Grateful unaffected (layout):** The Grateful card looks the same as before (record control below the field), but its **Save & add another** also continues recording if one was in progress.

## Decisions to confirm

- **D1 — Mic glyph + recording affordance.** Compact mic shows a mic glyph when idle and a stop glyph (red) while recording. **Proposed default: 🎤 idle → red ■ while recording.** A live numeric timer is not shown on the compact mic itself (the post-stop "voice ready · duration" line already reports length); recording state is conveyed by the red color. Surface this so we agree the dropped inline timer is acceptable.
- **D2 — Grateful card mic.** Leave Grateful's full-width record button as-is (proposed) vs. also make it compact. **Proposed default: leave as-is** — there's no context row for it to align with, so the full-width button stays the clearest affordance there.

## Rationale

- **Voice bursts are the point on a phone.** The journal's reason-for-being is fast capture; making a streak of voice entries a tap-speak-tap-speak rhythm (instead of tap-record-speak-stop-save-tap-record-…) removes the most repeated friction.
- **Controls that go together, sit together.** "How am I logging this" (Opportunity / Did-It) and "capture it" (mic) are one decision cluster; co-locating them shortens the visual path and frees the vertical space the old full-width button used.

## Cross-references

- The composer, cards, voice recording, Save vs Save-&-add-another: [Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md).
- "Save while recording finalizes the clip" (the behavior this extends): commit `c246fd7`.
