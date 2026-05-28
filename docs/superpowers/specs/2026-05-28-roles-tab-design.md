# Roles tab — design spec

> **Status:** Carved out 2026-05-28 from the larger [tabbed-app spec](2026-05-25-tabbed-app-design.md). The current build implements a small subset of the original vision; this doc separates **what ships today** from **the aspirational design** so we can iterate without ambiguity.

---

## Summary

The Roles tab is a living margin note on Igor's eulogy (idvork.in/eulogy). It tracks the 11 identity threads from the eulogy as roles — not goals, not metrics, not habits — and surfaces whether Igor is *living* each role on a 7-day horizon. Attention rules flag roles that have been quiet past their threshold. Manual tagging + a few auto-signals feed an activity score per role.

## Goals

- Make the eulogy operational — turn a static reflection document into an interactive identity check.
- "Am I living my eulogy this week?" should be answerable in one glance.
- "Where am I quiet?" should be answerable without thinking.
- Adding moments must take ~3 seconds (long-press → role picker → caption).

## Non-goals

- Streaks, flame icons, red error badges, "missed X" copy. Attention is warm, never alarming.
- Auto-judgment. The tab never says "good week" or "bad week."
- Calendar integration in v1 (the "Add to calendar" buttons are stubs).

---

## The 11 roles

Defined in `lib/roles.ts`; in eulogy order:

| # | Id | Name | Short | Attention threshold |
|---|---|---|---|---|
| 1 | `smiles` | Dealer of smiles & wonder | Smiles & wonder | 7 days |
| 2 | `carfree` | Mostly car-free spirit | Car-free | 5 days |
| 3 | `habits` | Disciple of 7 habits | Habits | 4 days |
| 4 | `fit` | Fit fellow | Fit | 5 days |
| 5 | `emo` | Emotionally healthy human | Emo | 3 days |
| 6 | `tech` | Technologist | Tech | 5 days |
| 7 | `pro` | Professional | Professional | 5 days |
| 8 | `family` | Family man | Family | 7 days |
| 9 | `tori` | Husband to Tori | Tori | 7 days |
| 10 | `amelia` | Father to Amelia | Amelia | 5 days |
| 11 | `zach` | Father to Zach | Zach | 5 days |

Each has a color, a raccoon avatar (`idvork.in/images/raccoon-*.webp` or Tabler fallback), and a verbatim eulogy passage.

---

## What ships today (current build)

This is what the Roles tab looks like RIGHT NOW. Iteration target should reference this baseline, not the aspirational section below.

### Layout (top → bottom)

1. **Header** — "Roles" title + "Living my eulogy" subtitle + "+ Tag moment" button (top right).
2. **Eulogy song card** — gold play button + "How I want to live" title + progress bar. Tap to play/pause.
3. **Needs attention card** — only renders when ≥1 role is attention-flagged. Lists up to 3 roles with avatar + reason ("Last shown 11 days ago"). Long-press → tag moment for that role.
4. **All 11 · this week** — every role as a row: avatar, name (short form), activity line ("3 gym · 6 days weighed"), 0–100 score pill. Long-press a row → tag moment for that role.
5. **Footnote** — small grey explanation of how scores work.

### How to add content (the only currently-supported interactions)

- **Long-press any role row** → opens TagMomentSheet pre-filled with that role.
- **Tap "+ Tag moment"** top-right → opens TagMomentSheet with no pre-filled role; pick one.
- **Workouts auto-tag** to `fit` / `habits` after a Grab Context fires `recordWorkoutMoments`.
- **Journal entries auto-tag** to `emo` via `recordJournalMoment`.
- **Meditation auto-tags** to `emo` via `recordMindfulMoment`.

There is no other UI to add or view content currently. Tapping a role row (no long-press) does nothing. There's no detail view.

### What's calculated

- **Activity score** (0–100): a per-role blend computed in `computeWeekActivity()` using `weeklyCache` (HealthKit) + tagged moments from the last 7 days.
- **Attention flag**: fires when "days since last tagged moment" exceeds the role's threshold. Reason string is human-readable.
- **Score pill is dim** when score < 25/100.

### Storage

- `role_moments` SQLite table: `id, role_id, timestamp, what, tag, source, source_ref, sync_state`.
- Sources: `manual`, `auto-workout`, `auto-mindful`, `auto-grateful`, `auto-journal`, `auto-place` (last two types defined but not all wired).
- **Moments should sync via CloudKit** so tagged moments follow Igor across devices (same pattern as `syncJournal` in `lib/cloudkit.ts`). The `sync_state` column already exists for this; CloudKit zone + push/pull functions are not wired yet. Tracked as a separate bead — orthogonal to the detail sheet, which reads/writes via the existing `lib/roleMoments.ts` API.

---

## Aspirational design (not yet built)

This is the original vision from `2026-05-25-tabbed-app-design.md`. Keeping it here so we can pick which pieces to actually build, in what order.

### Horizon switcher

A two-state segmented control at the top: **This week** / **This year**.

### This-week view (richer than today's flat list)

- **Constellation hero** — 11 colored role dots arranged on a faint ellipse. Dot size encodes this-week activity score; dimmed (50%) when the role needs attention. Tap a dot → role detail.
- **"Living my eulogy" headline** naming the 1–2 brightest and 1–2 quietest roles in their colors ("Strong as Technologist + Fit fellow. Quiet as Husband & Smiles & wonder.").
- **Needs attention** cards with eulogy markers + a suggested moment + a link into detail.
- **All 11 list** rows include a 7-bar week sparkline and a last-shown timestamp.
- **Weekly review card** — Sunday 5am promise, quotes the eulogy line on discipline.

### This-year view

- **11 × 52 heatmap** — each row a role, each cell a week, intensity = activity score. Tap row → detail.
- **Year in three numbers** — brightest role, dimmest role, most-variable role, weekly reviews logged.

### Role detail sheet (the biggest missing surface)

Tapping a role anywhere opens a slide-up sheet:

- Big avatar + role name + 3 identity-marker chips
- **Eulogy passage** as a left-bordered block quote
- **This week** signals grid (2-up)
- **52-week strip** with current week ringed + summary numbers
- **Bring it back this week** — 2–3 suggested moments with Add buttons (v1: stub)
- **Set an intention** composer — textarea, eulogy-voice prompt, saves to SQLite, surfaces on Today next week
- **Recent moments** log

### Attention rules (richer than the current single threshold)

A role is flagged when ANY of:
- Time since last shown > threshold
- This week's score < 25 AND last week's also < 25
- A flatline signal fires (meditation: 3+ days, date night: 14+ days)

### Auto-detection table (mostly aspirational)

| Source | Mapped roles | Status |
|---|---|---|
| HealthKit workout / exercise | Fit | ✅ shipped |
| HealthKit weight log | Fit | ❌ not wired |
| HealthKit sleep ≥ 6h | Emo, Fit | ❌ not wired |
| HealthKit mindful sessions | Emo | ✅ shipped |
| Gratitude entry | Emo | ❌ source defined, not wired |
| Journal entry (no tag) | Emo | ✅ shipped |
| GymTimer session completed | Fit | ❌ not wired |
| Location: walking > 2km/day | Car-free | ❌ |
| Location: "Office" known place | Professional | ❌ |
| Location: "Gym" known place | Fit | ❌ |
| Location: "Home" all weekend | Family, Husband, Father×2 | ❌ |
| App / git commits | Technologist | ❌ |
| Manual tag | Any | ✅ shipped |

### Intentions

A one-sentence weekly aim per role, set in the detail sheet composer. Stored with `role_id, week_start_date, text`. Surfaces on Today's hero the week it applies.

### Larry context export

`Grab Context` JSON gains a `roles` section at the top:

```
ROLES THIS WEEK
- Fit fellow (strong): 3 gym, 6 weighed days, 7.1h sleep avg
- Husband to Tori (quiet, last shown May 14): 0 date nights, 48m 1:1
ATTENTION
- Husband to Tori: no date night since May 14.
INTENTIONS
- (any saved intentions)
```

Leads the export, before the raw HealthKit + location summary.

---

## Decisions so far

- **Q1 — headline missing capability: Role detail sheet.** Tap a role → slide-up with eulogy passage + recent moments. **In active build (2026-05-28).** v1 scope is intentionally small (no 52-week strip, no "bring it back" suggestions, no intention composer); see "v1 scope" below.
- **Q2 — role row tap behavior: tap opens detail (B).** Tap a role row → opens the role detail sheet. Long-press is preserved as a power-user shortcut to log a moment without going through the sheet first.
- **Q3 — onboarding: persistent sub-header text (A).** A thin grey teaching line under "Living my eulogy": "Tap a role to see details · long-press to log a moment." Cheap, always visible, never dismissed.

### Role detail sheet — v1 scope

What ships in this build:

1. **Header**: medium avatar + full role name + close button.
2. **Eulogy passage** as a left-bordered block quote, tinted in the role color — verbatim from `ROLES[i].eulogyPassage`.
3. **Activity card** — this-week score (0–100 large), activity line ("3 gym · 6 days weighed"), attention chip if flagged.
4. **"+ Tag a moment"** primary CTA in the role color → opens the existing TagMomentSheet pre-filled with this role; sheet stays open behind it; recent-moments list refreshes on save.
5. **Recent moments** — last ~20 moments for this role from `role_moments` (via `getMomentsForRole`). Each row: time-since stamp, `what`, source chip (`manual` / `auto-workout` / etc).
6. **Empty state** for recent moments when the role has no logged moments yet — encourages tapping the CTA.

What is explicitly deferred to a later iteration:

- 52-week strip with current-week ring and summary numbers
- "Bring it back this week" — suggested moments with Add buttons
- "Set an intention" composer + Today-tab surface for intentions
- Identity-marker chips ("when Igor met Tori · lifelong partner · Tori-light, Igor-heavy")
- 2-up signals grid with trend chips and last-shown

## Open questions (to riff on)

These are the choices that block forward motion. Listed roughly in order of how much they unlock.

### Q1 — What's the headline missing capability? — **picked: Role detail sheet (A)**

The current flat list answers "where am I quiet?" via the attention card. It doesn't answer "what does this role look like over time?" or "what's a specific thing I can do this week?"

Options:
- **A. Role detail sheet** — tap a role → slide-up with eulogy passage + 7-day moments + intention composer.
- **B. Constellation hero** — visual at-a-glance of all 11 roles, replaces / sits above the list.
- **C. Year heatmap** — 11 × 52 view; "am I living my eulogy?" over the long horizon.
- **D. Auto-detection breadth** — wire up location, weight, gratitude, etc. so the scores reflect more of life without manual tagging.

### Q2 — Should "tap a role row" do something?

Currently long-press = tag a moment. Tap = nothing.

Options:
- **A.** Keep tap = nothing (the long-press idiom is fine, just needs onboarding).
- **B.** Tap opens the role detail sheet (Q1A); long-press still tags.
- **C.** Tap opens a tiny inline expansion showing the eulogy passage + recent moments; long-press still tags.

### Q3 — How does Igor learn to work it? — **picked: persistent sub-header text (A)**

You said "I don't know how to work it." Options:
- **A.** First-launch coach marks on the Roles tab ("Long-press to tag", "Watch attention chips").
- **B.** Persistent thin sub-header text under the title ("Long-press any role to log a moment.")
- **C.** Empty-state cards: when a role has 0 moments this week, render "Tag your first [role] moment" instead of a flat row.

### Q4 — What's the right horizon for the lead view?

This week (current) or this year (heatmap)?

Options:
- **A.** Week is the lead, year is one tab away.
- **B.** Year is the lead — the eulogy is a lifetime document, weekly noise distracts.
- **C.** A toggle between Week / Month / Year — three horizons.

### Q5 — Intentions: which surface owns them?

The aspirational design puts intentions in the role detail sheet (write here, surface on Today). But that means Today shows things from a tab Igor may not visit often.

Options:
- **A.** Intentions are role-scoped (set in role detail, surface on Today).
- **B.** Intentions are tab-level (one composer at the top of Roles, lists all this week's intentions).
- **C.** No intentions in v1 — pure observation, no aspiration entry.

---

## Acceptance criteria (current build only)

These match what's actually shipped, so we can verify regressions when we change things.

- [x] All 11 roles render with avatar + color
- [x] Long-press any role row opens the TagMomentSheet pre-filled with that role
- [x] "+ Tag moment" button opens the TagMomentSheet with no pre-filled role
- [x] Tagged moment appears in the activity score within 7 days
- [x] Workouts auto-tag to `fit` after a grab
- [x] Journal entries auto-tag to `emo`
- [x] Meditation auto-tags to `emo`
- [x] "Needs attention" card lists up to 3 roles whose threshold has elapsed
- [x] Activity score is dimmed when < 25/100
- [x] Eulogy song plays / pauses on the gold button

Aspirational acceptance criteria (constellation, heatmap, detail sheet, intentions, Larry export with roles section) live in `2026-05-25-tabbed-app-design.md` and remain unimplemented.

---

## Implementation pointers (read-only references)

- Screen: `screens/RolesScreen.tsx`
- Activity scoring: `lib/roles.ts` (`computeWeekActivity`, `computeAttention`)
- Moment storage: `lib/roleMoments.ts` (SQLite CRUD)
- Auto-tag hooks: `lib/autoDetect.ts` (workout, journal, meditation)
- Tag sheet UI: `components/TagMomentSheet.tsx`
- Eulogy song player: `components/EulogySongCard.tsx`
- Avatars: `components/RoleAvatar.tsx`
