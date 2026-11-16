# Larry edits the board: making room and plain text (step 1)

Status: draft for Igor, 2026-11-16. Step 1 built (stories 814–819).

## The idea in one line

Larry can change the board itself, not only draw ghosts on it. In this first step he can open space between lines
and put down real, readable text. Each change he makes is one undo for Igor.

## Why

- Igor asked Larry on the board, 2026-11-16, to "stick 20 lines between here and here", and Larry had no way to do it.
  He can only draw into empty space.
- A kept label sits on top of Igor's ink instead of pushing it down (#894).
- Larry's labels are drawn in a traced hand font that is hard to read small (#895).
- Igor, 2026-11-16: more of the board's behaviour should live on Larry's side, so it can change without an iPad
  build. The app applies what Larry asks for, and Larry decides what to ask. This is the first step of that split
  (Larry's plan, thread igor2-88g.1499: step 1 here, objects and editing next, server-drawn controls last).

## What Igor sees

### Larry makes room

- Larry answers a turn with "make room here". Everything on the board below that line, including Igor's ink, pictures,
  pasted text and kept marks, slides straight down by the amount Larry asked for. Nothing is scaled, split or
  redrawn; whole strokes move.
- The board grows a page at the bottom when the push needs one. It never loses ink off the end.
- One tap on Undo puts everything back where it was, page count included. Redo pushes it down again.
- If Igor is drawing when the answer arrives (the Pencil is down, or was lifted less than a moment ago), the push
  waits until he lifts it. A push never moves ink under a live pen.
- If Igor changed the board after Larry looked, the push is not applied, and Larry is told so. Larry looks again and
  sends a fresh one. Igor never sees a half-applied change or a push in the wrong place.

### Larry writes plain text

- Larry can put a line of text on the board in a plain, readable typeface, at a size and colour he picks, instead of
  a traced hand font. It reads cleanly at small sizes.
- The text is a mark like his others: it arrives as a ghost. Keeping it makes it part of the board, Dismiss throws it
  away, and Undo takes it back.
- Kept text is part of the page. It shows in the board's picture and in what Larry gets back. It moves with a push
  like any ink.

### Larry hears the pen and taps

- Larry learns when the Pencil goes down and comes up. He can wait for Igor to finish before answering, and never
  pushes ink mid-stroke.
- Larry learns when Igor taps the board, and whether the tap landed on one of his marks. That is enough for him to
  offer tap-to-keep, or a tappable band where room will open.

### Driven from the web or from the app (Igor, 2026-11-16)

- The board takes changes from one place, whoever sends them. Today that is Larry over the network. Later, Larry's
  own board rules can run inside the app, so some features work offline and without a round trip.
- Igor sees the same behaviour from either: the same push, the same text, the same single undo.
- Which features run locally is a subset still to be decided. Anything not decided runs from the web.
- Turning a source on or off never needs Igor to do anything, and a board never takes the same change twice.

## Edge cases

- Several changes in one answer, such as making room and then placing text in the gap, are applied together as one
  undo, or not at all.
- A push asked for at a line below the last ink just adds blank paper; nothing moves.
- An answer with changes for a different board, or for a board that was deleted, is ignored and logged.
- With no network, Igor's ink works as it does today. Larry's changes simply don't arrive until he can answer.
- Older builds that don't understand a change ignore it and show Larry's answer as they do today. Nothing breaks.

## Non-goals (this step)

- Objects that move as one, lasso to group, and editing a kept label's words (step 2, #912).
- Larry drawing buttons, bands or chips on the board (step 3).
- Folding sections, scratch-out to delete, and smart arrows.
- Running Larry's board logic inside the app for offline use.

## Acceptance

- Larry asks for room below a line on a board with ink above and below it. The ink below moves down exactly that
  far, the ink above doesn't move, and one Undo restores the board exactly.
- A push that needs another page adds one. Undo removes it again.
- With the Pencil down, a push waits, then applies within a second of the Pencil lifting.
- When Igor drew after Larry looked, the push is refused, nothing moves, Larry is told why, and his next answer
  applies.
- Larry's plain text arrives as a ghost, keeps on a tap, reads in a plain typeface, shows in the next picture Larry
  gets, and moves with a later push.
- The session log has one line per applied or refused change, with what moved and why, for a phone check.
