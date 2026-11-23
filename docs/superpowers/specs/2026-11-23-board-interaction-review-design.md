# Reviewing each writing session on a board

**Status: approved by Igor, 2026-11-23** ("That design is approved, and it should work on the web board as well"),
with the proposed answers to his open questions (see *Decisions*). Plan:
[2026-11-23-board-interaction-review-plan.md](../plans/2026-11-23-board-interaction-review-plan.md). Stories 1237–1262
in [storage, sync and the log](../../stories/10-whiteboard-storage-and-log.md#user-story-1237); bead
`context-grabber-8ao5`.

Igor, 2026-11-23: every writing session on a board should be reviewed afterwards for bugs, the ones insertion causes
and the ones what he did causes, and it should be a shared core feature so the iPad and the web board both get it.
Larry, the same day: "The interaction review sounds right to me: replay each session through the shared rules and flag
any step where new writing landed inside a fold, under ink, or got moved. Your spec, my web side."

## Summary

After Igor writes on a board, the board looks back over what just happened, one step at a time, and asks the board's
own rules whether each step did what it should have. A step where new writing landed inside a fold, landed on ink
already there, or moved ink nobody asked to move is a finding. Igor sees a quiet note on the board, a finding he can
copy with the step and its evidence, and a way to replay that step. Larry gets the findings too.

The review is what the manual review of 2026-11-23 did by hand, reading the iPad's session logs against the stories,
made routine: the same questions, asked of every session, with the same kind of evidence, and the same answer on the
iPad and on the web board, because both ask the same rules.

## Why

- Insertion bugs are quiet. Ten new strokes went into a 145-stroke fold on Igor's board (2026-11-23) and nothing said
  so until he went looking. A bug that hides or moves his writing costs a thought, and he may not notice it at all.
- Today a review is an agent reading logs for an hour. It found the right things (a reflow working as designed, a
  stretch whose intent was unclear, no bug), but it ran once, for one evening.
- Most of what a review asks is a rule the board already has: where a fold ends, where a paste lands, how far a drop
  pushes, what an Undo puts back. Replaying a session through those rules, and comparing with what actually happened,
  turns each rule into its own check.

## Goals

- Every writing session on a board gets reviewed, without Igor asking.
- Each finding names the step, the rule, and the evidence, and can be copied and replayed.
- The same session gives the same findings on the iPad and on the web board.
- A finding tells a bug from something that worked as designed and from something whose intent is unclear.
- Larry sees the findings, so he can raise them and so the web board's side is checked by the same review.
- A review never changes the board.

## Non-goals

- Not fixing anything. A review reports; a fix is a bead and a story, as now.
- Not judging the writing itself: what Igor wrote, its handwriting, its spelling or its sense.
- Not filing GitHub issues or beads by itself (*Decisions*, 3).
- Not a replacement for the session log or for BugKit's reports: those stay as they are, and a finding links to them
  where it can.
- Not checking a surface for what it cannot see. A check a surface did not record reads *not checked* there, and one
  it saw only roughly reads *approximate*, never *clean*.
- Not the Cockpit's own failures (Larry not answering, an HTTP 502). Those are already reported elsewhere.

## What a session is, and what is recorded

A **session** is one stretch of work on one board: from when the board opens until it closes, or until it has been
idle for the review's wait (below), whichever is first. Writing after that starts a new session.

For each session the board keeps a **record**: the board as it was when the session began, then every **step** in
order. A step is anything that changed the board or what was selected on it:

- Igor's ink: a stroke drawn, erased, scratched out, or snapped to a shape.
- Igor's choices: a selection made or cleared, a drag, a menu choice (Make room, Select, Delete, To text, Fold,
  Unfold, Fold all, Collapse, Not a header), a paste, a pen picked.
- Larry's and Claude's turns arriving: their marks shown, kept, dismissed, or a batch of Larry's changes applied.
- The board's own moves: room opened, a drop pushing writing down, owners put apart, a fold or unfold.
- The system's moves on the iPad: a handwriting reflow, a stretch, a selection taken by a popover.
- Undo and Redo, with the name of the step they took back or put back.

For each step the record keeps:

- **When** it happened, and **who started it**: Igor's hand (Pencil or finger), Igor's menu choice, Larry, Claude, the
  board's own rule, or the system.
- **What it was aimed at**: the selection, the thing a menu was opened on, the place a paste or drop was asked for.
  This is what tells a move he meant from one he didn't.
- **What changed**: each stroke, text and card added, removed, hidden, shown, moved or resized, by whose it is (Igor's,
  Larry's, Claude's), with where it was before and after.
- **The folds** before and after: which headers were folded and what each held.
- **What the surface saw** that the board's ink cannot say: whether a selection held, which pen was in hand before and
  after, whether kept ink drew whole and in its colour. Each surface records what it can, and says what it couldn't.

The record holds board geometry, not pixels or words: what Igor wrote is in it only as strokes, as the board itself
holds it. It stays on the device that made it, for 14 days, and never syncs (*Decisions*, 2).

## When a review runs

Both:

- **On its own**, once the board has been idle for five minutes after writing (five minutes with no step), and
  when the board closes after a session with at least one step. A session cut short by the app closing is reviewed
  the next time the board opens.
- **On demand**, from the board's menu: *Review this session*. It reviews the session so far, and again from its
  start if asked later; asking twice gives the same findings.

A session with no step of Igor's (the board only opened and looked at) is not reviewed. A review runs in the
background and never holds up writing; a board opened again while a review runs gets its note when it finishes.

## The checks

Each check replays the session's steps through the board's shared rules and compares what the rules say should have
happened with what the record says did. Every finding gets one of three verdicts:

- **Bug**: the step broke a rule the stories set.
- **As designed**: something surprising happened and a rule handled it (the review says which story). Shown so Igor
  knows it was seen, never counted as a bug.
- **Unclear**: the review can't tell from the record whether Igor meant it. It asks him.

A check also carries how well the surface could see, alongside its verdicts:

- **Not checked**: the surface didn't record what the check needs, for that session. Never shown as clean.
- **Approximate**: the surface recorded something close to what the check needs but not exactly it (the web board's
  pen in hand, which it knows from the last input rather than from the tool held). A finding from an approximate
  check is at most *unclear*, never a bug, and a clean approximate check says *approximate*, not clean.

**Positions compare with a tolerance**: a move of under half a point is no move, and two things that only touch
(share an edge) do not overlap. Both are far above the difference between the iPad's arithmetic and the web's, so a
session gives the same findings on both.

### 1. Writing landed inside a fold

- **Rule**: ink added in a step (Igor's stroke, a paste, a text of Larry's set, a kept mark) shows after the step, and
  no fold holds more after a step that only added ink than it held before.
- **Bug**: new ink is hidden the moment it lands, or a fold's hidden set grew by it without a fold step.
- **Not a finding**: ink written on a folded header's own line that joins the header, as the header rules say.
- **Evidence**: the step, the header, the new strokes' ids and box, the fold's count before and after.

### 2. Writing landed under existing ink

- **Rule**: anything the board places (a paste, a drop, a kept mark, a text of Larry's, a late reply kept, ink a room
  or push moved) lands where it overlaps no ink that showed before the step, or room opens for it by the room rules.
- **Bug**: the placed thing's ink crosses ink that showed before, by more than the tolerance, and no room opened, or
  the room that opened was less than the rules say.
- **Not a finding**: Igor's own pen writing over ink. He underlines, strikes through, annotates and scratches out on
  purpose; only what the board places is checked.
- **Evidence**: the step, what was placed and where, the ink it lands on (ids, owner, box), the room the rules called
  for and the room that opened.

### 3. Igor's ink moved without his intent

- **Rule**: Igor's strokes move or change size only when the step was aimed at them (his selection, his drag, his menu
  choice on them), or when a rule moves them as that step calls for: a room or a drop's push by the amount and from
  the line the rules give, a fold's slide, Larry's batch where it names them.
- **Bug**: his strokes moved that the step wasn't aimed at and no rule moved; or a push moved them by a different
  amount or from a different line than the rules give; or a drag that started inside a selection changed its size
  (story 1201).
- **Unclear**: the system moved or stretched his strokes from a handle (a reflow handle) with no selection of his own
  behind it; or a selection, his or a kept mark of Larry's, changed size under a drag that began on its corner knob,
  which stretches by design (story 1201) but may not be what he meant. The review shows the before and after and asks
  whether he meant it. (The 13-point stretch of Larry's kept reply on 2026-11-23 at 05:28, a group tap's selection
  dragged from its knob, is the second case.)
- **Judged once the step settles**: a move and the owners-apart step that follows it are one step here, so strokes the
  rules put back in place (the 05:15 reflow's 18) never read as moved.
- **Evidence**: the step, who started it, the strokes moved, their move (smallest and largest dx and dy, and whether
  they moved alike or unevenly), what the rules predicted.

### 4. Larry's ink moved with Igor's

- **Rule**: one step never leaves both owners' ink moved together unless Igor selected both himself. When the system
  moves both, one owner's go back (stories 1145, 1146).
- **Bug**: after the step settles, ink of both owners stays moved by one step he didn't aim at both.
- **As designed**: the system moved both and the owners were put apart (the 2026-11-23 reflow at 05:15: Larry's 110
  kept the move, Igor's 18 went back).
- **Evidence**: the step, each owner's strokes and their moves, what went back.

### 5. A fold swallowed new ink

- **Rule**: folding a header hides its section and nothing else. Ink written under a folded header after it was folded
  stays outside its fold when it is folded again (story 1231); unfolding and folding with nothing written hides the same
  ink as before (story 1232).
- **Bug**: a fold step hid ink the rules say is outside the section, in particular ink newer than the header's last
  fold.
- **Evidence**: the step, the header, the ink the rules say the fold holds and the ink it hid, with the extra ink's
  ids, times and box (the 2026-11-23 case on Igor's board: ten new strokes went into a 145-stroke fold).

### 6. An Undo that didn't restore

- **Rule**: after an Undo, the board is as it was before the step undone: the same ink showing, in the same places,
  the same folds. After a Redo, as it was after that step.
- **Bug**: anything differs past the tolerance: a stroke missing, a stroke left where the step moved it, a fold left
  open or closed. Also an Undo that took back a step other than the one its name said.
- **Evidence**: the Undo, the step it took back, and what differs (ids, before and after).

### 7. A selection lost

- **Rule**: a selection Igor made stays until he clears it, taps elsewhere, or a step uses it up (a delete, a move
  finished, a menu choice that ends it).
- **Bug**: it went with nothing of his to end it and didn't come back.
- **As designed**: it was taken (by the handwriting popover, say) and put back at once (stories 946, 949).
- **Evidence**: the selection (what, how many), what took it, whether and when it came back.
- Needs the surface's observation. The web board records it if it can (*Larry's answer*, 7: it does).

### 8. A kept mark changed his pen

- **Rule**: keeping a mark of Larry's leaves Igor holding the pen he held before: same tool, colour and width.
- **Bug**: the pen after the keep differs, with no pen picked between.
- **Evidence**: the keep, the pen before and after.
- Needs the surface's observation. On the web board it is approximate (*Larry's answer*, 8).

### 9. A kept mark drawn cut

- **Rule**: a kept mark draws whole, in its own colour, once the board has finished drawing it.
- **Bug**: part of it is missing, or it drew in another colour (black for Larry's purple), after the board's own
  redraws have had their chance.
- **As designed**: it drew cut at first and a redraw healed it (counted, so a heal that is needed often shows).
- **Evidence**: the keep, how much of the mark showed against how much should, its colour, the redraws tried.
- Needs the surface's observation of what it drew. The web board records it from its keep (*Larry's answer*, 9).

The first six are answered by the rules from the record alone, so they give the same answer wherever the record is
replayed. The last three depend on what a surface saw, and are as good as its record of it.

## What Igor sees

- **A quiet note per board, only when there is something to look at.** After a review with a bug or an unclear
  finding, the board's corner shows a small line, never a sheet or an alert: *Reviewed · 1 to look at*. Findings
  marked *as designed* don't count toward it. A clean review of its own shows nothing at all; one he asked for from
  the menu says *Reviewed · clean*, since he is waiting for an answer. The note goes once he has opened it, or with
  his next stroke.
- **The findings.** A tap on the note lists them, newest first: when, the check, the verdict, one line of what
  happened (*10 new strokes went into the fold under "Plans"*). A clean review lists what it checked and what it
  couldn't.
- **Each finding copyable**, as every error in the app is: the check, the verdict, the step (its time, what it was,
  who started it), the evidence as above, the board and session, the build. Enough to file without the log.
- **Replay that step.** Each finding has *Show me*: the board's playback opens at that step and shows the board just
  before, then just after, with the ink the finding names marked. Ink erased by that step shows in the
  *before*, as it was, because the review is honest about what happened. Unclear findings also offer *I meant that* and
  *Not what I meant*.

## How Larry gets findings

- With the next picture of that board he receives (not a post of its own, and not only on the Cockpit's debug page), a short list of the session's findings: counts by check and
  verdict, then each finding that is a bug or unclear, as its copyable text. A clean session is one line.
- Igor's answers to unclear findings go with them, so Larry learns what Igor meant.
- The web board's reviews reach Larry the same way, so a finding is a finding whichever surface found it.

## False positives

- **A deliberate move isn't a finding.** Intent comes from the step: what Igor selected, dragged or chose a menu on is
  meant to move, and so is whatever the rules say that step pushes or slides. Only movement outside both is flagged.
- **When the review can't tell, it asks** (*unclear*) instead of calling a bug.
- **Igor answers an unclear finding** (*I meant that*, *Not what I meant*). Either answer takes it off the note; it
  stays in the session's list marked with his answer, and goes to Larry with the rest. The review doesn't learn from
  answers on its own: a rule whose findings keep getting *I meant that* is a change to its spec, decided with Igor.
- **The same finding twice** (a re-review, or the same step seen by two checks) shows once.

## The iPad and the web board, through one core

- Both surfaces write the same record, in the same form, and the same review reads it: the review is part of the
  board's shared rules, as the fold, room and drop rules are.
- A record made on either surface reviews to the same findings on the other: replay the iPad's session on the web or
  the web's on the Mac, and the list is the same.
- What differs is only what a surface can see. The web board has no handwriting reflow, popover or PaperKit
  drawing, so those steps never happen there. It observes all three checks that need a surface's eyes, the pen in
  hand only approximately, so check 8 reads *approximate* there.
- The web board's recording, its note and its findings list are Larry's to build; the record's form, the checks and
  their verdicts are shared.

## Acceptance criteria

- A board idle for the review's wait after writing shows a review note; *Review this session* gives the same findings
  as the automatic review of the same session.
- A review never changes the board, its Undo stack or its folds.
- The iPad sessions of 2026-11-22 and 2026-11-23, as their logs tell them, review to the manual review's verdict:
  no bug; the 05:15 reflow *as designed* (story 1145); the 05:28 knob stretch *unclear*; the four keeps clean on
  pen and drawing; the selections lost to the popover *as designed*, each put back on the first try.
- Each closed bead's own case, recorded, is flagged by its check: ink written under a fold swallowed on refolding
  (context-grabber-eysh), an Undo that left a line cut (9bll, where its record has the observation), a kept mark drawn
  black (pbvt) or cut (dell), a selection lost to the popover and never put back (4nnh, before its fix), the reflow
  moving both owners together (eg7v, before its fix), a drag inside a selection stretching it (vhae).
- Each check has a session where it is clean and one where it fires, and the deliberate version of each move (a
  selection dragged, a room asked for, a fold asked for) is not flagged.
- The same records reviewed on the Mac and through the web board's rules give the same findings, verdict for
  verdict.
- A check the surface didn't record reads *not checked*, and one it saw only roughly reads *approximate*; neither
  ever reads clean. An approximate check never calls a bug.
- Every finding copies as text with the step, the rule and the evidence.
- The recorded sessions used as tests are scrubbed as the board sessions already are: no words, and strokes reduced to
  their geometry.

## Decisions

Igor approved the spec on 2026-11-23 with the proposed answers to his questions:

1. **Idle is five minutes** with no step. A review also runs when the board closes.
2. **A record is kept on the device that made it, for 14 days**, and deleted with its board. It never syncs.
3. **A finding never files anything by itself.** It is copied, or sent to Larry, and a bead is filed from there.
4. **Larry gets the findings with the board's next picture.**
5. ***Show me* shows ink that was erased**, in the *before* of the step that erased it.
6. **A clean review shows nothing.** Only a finding to look at puts a note on the board (or a review he asked for).

## Larry's answer: what the web board observes

Larry, 2026-11-23, answering question 7: the web board can supply all three checks that need a surface's eyes.

7. **A selection held: yes.** The page holds the lasso's selection until it is cleared and logs every change to it.
8. **The pen in hand: approximate.** The page knows the pen type of every stroke, but between strokes it can see the
   Pencil only on iPads that report hovering, so the web board says *the last input was the Pencil within a few
   seconds*. Check 8 on the web board reads *approximate*, never *not checked*.
9. **A kept mark drawn whole: yes.** A keep takes a mark as one group with one Undo, and the page logs the keep and its
   ids.

So the web board reports all nine checks, with check 8 marked approximate.
