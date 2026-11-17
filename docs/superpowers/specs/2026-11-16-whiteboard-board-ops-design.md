# Larry edits the board: making room and plain text (step 1)

Status: draft for Igor, 2026-11-16. Step 1 built (stories 814–819); steps 2 and 3 below (Igor via Larry, 2026-11-16: build them all in one round, one simulator pass at the end).

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

## Step 2: Larry edits the ink itself

The web board (the Cockpit's `/ink`) is where these behaviours are worked out first; the iPad board follows it.

### Larry draws, erases and replaces ink

- Larry can put ink straight onto the board: real strokes, not ghosts, at the width and colour he chooses. They are
  part of the page from that moment, show in the next picture, and come back to him under the names he gave them.
- He can erase strokes by name, and replace some strokes with others (tidying a scrawl into a clean line, say) in a
  single step.
- Each answer of his is still one undo: Undo takes back everything that answer did, the strokes he drew, the ones he
  erased and the ones he moved, page count included.

### Larry groups ink

- Larry can tag strokes with notes of his own. The board never reads them, except one: a group. Strokes in one
  group move as one when he pushes or moves them, so a label and its underline never split.
- His notes go back to him exactly as he wrote them, with the strokes they belong to.

### Larry hears my ink change and my selection

- After each change Igor makes, Larry learns which strokes were added, which were erased and which Igor moved, by
  name, and the board's revision after it. A stroke Igor moves keeps its name, as one Larry moves does.
- When Igor circles ink with the lasso, Larry learns which strokes are selected.

## Step 3: Larry's controls on the board

### Bands, chips, buttons and hints

- Larry can lay a few controls on the board: a band (a strip across the page, such as "room opens here"), a chip, a
  button, or a hint. Each sits at a place on the board, scrolls with it, and carries a short label. They are not ink:
  they are never in the picture, never in the strokes, and never undone. He takes them away when he is done with them.
- A tap on one reaches Larry at once, without waiting for Igor's next turn, and wakes him: it is a tap on his control,
  naming which, with the event he asked to hear carried as he wrote it. (A plain tap on the board never wakes him.)
  If the Cockpit can't take it straight away, it goes with the next turn instead, and the session log says so.
- What the board sends Larry keeps to the Cockpit's limits: at most 200 events at once, none bigger than 8 KB, and the
  whole under 256 KB. An event too big is left out, and when there are too many the oldest go; either way he is told
  how many he missed.

### Larry folds and selects

- Larry can hide strokes and show them again, as a folded section would. Hidden ink is still on the board: it keeps
  its place, moves with a push, and comes back when he shows it. Hiding is part of his answer's one undo.
- Larry can select strokes for Igor, as if Igor had circled them with the lasso, ready for Igor to move or delete.

### Larry hears the margin, the view and Undo

- A finger in the board's left margin tells Larry what it did there: a tap, a hold, or a drag and how far, with where
  on the board it was. That is how Igor will ask for room by hand.
- When Igor stops scrolling or zooming, Larry learns what part of the board is on screen and at what zoom.
- When Igor undoes one of Larry's changes, Larry learns which one, by its name.

## Non-goals

- Editing a kept label's words (#912).
- Scratch-out to delete, and smart arrows.
- Running Larry's board logic inside the app for offline use.
- Controls that survive the board closing: they are Larry's live conversation, and he lays them again.

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
- Larry draws two strokes, erases one of Igor's and replaces another: all of it shows at once, one Undo takes all of
  it back, and his strokes come back to him under his names.
- A push moves a group whole, even when only some of it is below the line. His notes come back with the strokes.
- Igor draws, erases and lasso-moves: Larry's next turn names what was added, erased and moved, and the moved
  strokes keep their names. A lasso selection is named too.
- A band Larry lays shows at its place and scrolls with the board; a tap on it reaches him within a second.
- Hidden ink vanishes and returns on his word, and moves with a push while hidden.
- A margin tap, hold and drag, the end of a scroll, and an undo of his change each reach him on the next turn.
