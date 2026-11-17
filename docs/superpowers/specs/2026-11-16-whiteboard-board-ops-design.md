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

## Step 4: the board behaves like Larry's web board

Igor, 2026-11-16: the web board at /ink is the behaviour to match, its model and its gestures alike; where the iPad
board differs, this says why.

### Paste makes room

- A paste never lands on ink. It goes to the clear patch of the screen nearest its middle that holds it whole with
  half a line of air round it, right of the margin and on the page.
- When no clear patch holds it, room opens at the clear line nearest the middle of the screen: the ink below moves
  down, whole things whole, by as many whole lines as the paste needs beyond the blank paper already there, and the
  paste lands at the top of that room against the margin. It is the same push as Larry's *make room*.
- The push and the paste are one Undo, named *Paste*. A push that needs another page adds it, and Undo takes it away.
- The paste lands selected, with **Delete** beside it. Delete takes the paste away (one Undo); the room it opened
  stays, as on the web board. Selecting anything else, or any change to the ink, puts Delete away.
- Ink folded away (below) is no obstacle: a paste may land where a folded section's hidden lines are.

### Erasing part of a group dissolves it

- When Igor's eraser takes some, not all, of the strokes of a group (one of Larry's groups, or the letters of a
  text of his that Igor kept), what is left is plain ink: it no longer moves as one thing, and Larry's next turn no
  longer calls it his group or his text. The strokes that are left keep their names.
- Larry is told, with the strokes that went, which groups dissolved.
- Erasing a whole group, or a stroke in no group, is an ordinary erase.

### Headers fold their sections

- **A finger tap in the left margin beside a line makes that line a header.** A small ▾ shows in the margin beside it.
  A tap beside a header folds it (the mark turns ▸ with the number of lines folded) and a tap again unfolds it.
  A tap beside blank paper does nothing.
- **A section ends where the ink comes back to the header's indent.** It runs from the line below the header to the
  first line that starts at or left of the header's own left edge (within half a line), or to the next header at the
  same indent or shallower. Blank paper never ends a section. When the line under a header isn't indented at all, the
  section runs to the next header at its indent or shallower. A deeper header inside a section is its own header, and
  folds on its own: folds nest.
- **Folded lines hide and the board closes up.** What is below the section slides up to sit a line or two under the
  header, in whole lines. Unfolding puts it back; anything written under the folded header meanwhile moves down below
  the section rather than being drawn over.
- A fold is one Undo, named *Fold* or *Unfold*. (The web board's folds are not undo steps; on paper every change is,
  and an Undo of an earlier step would otherwise spring a fold open.)
- Folded ink is still on the board: it moves with its header, a push never splits it from its header, and it is in no
  picture. Larry is told which strokes are folded under which header and how many lines, so folded ink is never taken
  for erased, nor for new when it unfolds.
- Headers are kept with the board on this device, by the names of their strokes.
- **Fold all and Unfold all**, and **collapse to a level**: from the hold menu on a header's mark, Fold all, 1, 2, 3
  and Unfold all. A header's level is how deep it nests with everything open. Collapsing to level *n* shows the
  headers down to level *n* and nothing deeper: every header at level *n* folds, and so does a shallower one with no
  headers under it; a shallower one with headers under it stays open.
- **A line that looks like a header shows a faint H in the margin**: one written well bigger than his usual lines
  (1.5 times his usual line height and 1.6 times his usual letters, once the board has four lines of his to judge by,
  three strokes or more, wider than tall), or one underlined across most of its width. It is only a suggestion: it
  doesn't fold and isn't kept until his margin tap there makes it a header.

### Press and hold (#918)

- **A finger or the Pencil held still in the margin, then dragged**, opens room at the clear line nearest where it
  went down, by the drag in whole lines when he lifts; dragged up it closes blank paper only, never past the ink
  above. One Undo. (Igor, 2026-11-16, on the iPad: "push down doesn't seem to fire at all" — he reached for the
  margin with the Pencil, and the Pencil only drew.)
- **The Pencil in the margin is the handle only once it has held still**: it went down in the margin and stayed
  within about 12 points of there for half a second (a hand on a Pencil drifts; Igor's two long holds drifted past
  10). Once it has held, any drift is part of the drag. A Pencil that moves further sooner, or lifts sooner, draws as
  ever, so quick bullets and dashes in the margin stay ink. A hold leaves no ink behind: the stroke the Pencil drew
  while holding and dragging is taken away. Held on a header's mark, the Pencil brings up the outline menu whatever
  the drag, as a finger does.
- **A finger or the Pencil held still in the margin, not dragged**, or **a finger held still anywhere on the page**,
  brings up a small menu:
  *Make room here* (three lines, at the clear line nearest the finger), *Paste*, and *Make header* beside a line of
  ink (*Not a header* beside a header). Held on a header's mark, the menu is the outline: *Fold all*, *1*, *2*, *3*,
  *Unfold all*.
- **The Pencil held still on ink for 400 ms picks up the word under it**: the strokes on that line chained while the
  gap between them is under 16 points (a group of Larry's, a kept text or a header row whole). The same stroke drags
  it, and where the Pencil lifts it lands; the Pencil's own stroke is not kept. One Undo, named *Move*. Held still
  and lifted without moving, the word is left selected. Off ink, a held Pencil draws as ever. In the margin a
  held Pencil is the hold above, never the pick-up, as a finger's is.
- On paper the word lands, and the room opens, when the Pencil lifts rather than following it live; PaperKit owns
  the stroke while it is drawn.
- Every hold tried in the margin is in the session log: when it began, with the finger or the Pencil and where, and
  whether it became a hold or why not (it moved first, it lifted too soon, or the board never saw it held), so a
  phone's log says what happened to a hold that didn't fire.

## Step 5: connectors (smart arrows)

Igor, 2026-11-16: the board's arrows should be smart, as on the web board (/ink): an arrow that joins two things and
stays joined when they move.

### What a connector is

- A connector is an arrow from one thing on the board to another: a kept text, a group of Larry's, or a word of Igor's.
  Its tail leaves the first thing's side that faces the second, and its head lands on the second's side that faces
  the first.
- It runs straight, unless a straight line would cross another thing (a kept text or a group). Then it bends once, an
  L made of a level and an upright leg, if either L crosses nothing. If neither does, it runs straight anyway.
- It follows its ends. When either one moves, whoever moved it (Igor's lasso, a word picked up with the Pencil, a
  push, a paste making room, a fold closing up, or Larry), the arrow is drawn again from where they are now. The
  redraw is part of that move's own Undo. When an end is folded away, the arrow points at the header that hides it.
- The eraser takes a connector whole, as any stroke, and nothing else of it is left.
- When one of its ends goes (erased, or a group or a kept text that came apart), the arrow stays where it was, as plain
  ink, as on the web board.

### Igor makes one

- Igor draws an arrow, by hand, from one thing to another, and circles it with the lasso. When both of its ends land on
  something (within 16 points), a **Connect** button shows beside the selection.
- Connect takes his drawn arrow away and puts a clean connector in its place, joining the two things. One Undo,
  named *Connect*, gives his own arrow back.
- The head is the end nearest the rest of the strokes he circled (the arrowhead). With only one stroke circled, the
  head is where the stroke ended.
- An end on a word of his makes that word one thing: from then on it moves whole, as one of Larry's groups does, and
  rubbing out part of it makes it plain ink again (and the connector plain ink with it).

### Larry makes one

- Larry can draw a connector as one of his changes: its name and its two ends, each the name of a stroke, group or
  kept text on the board, or a point on the board. A point takes the smallest thing under it (within 16 points), or
  else the word there.
- An end that names nothing on the board draws nothing, and Larry is told which name was missing. With an end at a
  point on bare paper, the arrow is drawn as plain ink between the two points, as the web board keeps such an arrow.
- It is part of his answer's one Undo, like his ink. He can erase it by its name.

### What Larry gets back

- A connector goes back to Larry with the board's strokes, as a stroke under its name, so it shows in every picture he
  renders. Its notes say what it is: a connector, what it joins (by name), the sides its ends leave and land on, and
  the points of its route.
- Larry hears Igor make one as he hears any ink change: his arrow's strokes erased and the connector added.

### Known limits

- Undoing a Connect gives Igor's own arrow back, but a word that Connect made one thing stays one thing.
- Connectors in Larry's chat-reply shapes are not handled yet: only his board changes draw them.
- Larry's connectors are drawn after the rest of his changes in the same answer, on the board those changes leave.

## Non-goals

- Editing a kept label's words (#912).
- Scratch-out to delete (another build).
- A connector made by dragging from one thing to another (the web board's way is the lasso and Connect), and a
  connector between two plain strokes that aren't a word.
- Question cards, the writing pause learned from his rhythm, tidying overlaps (other builds).
- The picture showing "▸ N lines folded" under a folded header, as the web board's does: the margin mark shows it
  on the board, and Larry gets the count with the strokes.
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
- A paste over a full screen opens room at the middle: the ink below moves down whole lines, the paste sits in the
  room, selected with Delete beside it, and one Undo takes both the paste and the room away. On a screen with a clear
  patch the paste lands there and nothing moves.
- Rubbing out one stroke of Larry's group leaves the rest as plain ink; his next turn says the group dissolved.
- A margin tap beside a line makes it a header; a tap beside it folds its indented lines and the ink below closes up;
  another tap brings them back where they were. Folding a section holding a folded header and unfolding it leaves the
  inner one folded. Larry's next turn lists the folded strokes under their header, and none of them as erased.
- Fold all, 1, 2 and Unfold all on a two-level outline show what the outline would.
- A line written big or underlined shows a faint H; a margin tap there makes it a header.
- A finger held in the margin and dragged down two lines opens two lines; held and lifted, or held on the page, it
  shows the menu. The Pencil held on a word for under half a second and dragged moves that word, and nothing else.
- A connector from one group to another is drawn straight; a group put between them makes it bend once around it;
  moving that group away straightens it again. Lasso-moving an end redraws the arrow to it, and one Undo puts both
  back.
- Igor lassos an arrow he drew from a word to a kept text: Connect shows, and a tap leaves a clean arrow between them
  that follows either one when it moves. One Undo gives his arrow back.
- Larry's connector by names and by points both land; one naming nothing draws nothing and is reported missing; one
  with an end on bare paper is plain ink.
- Erasing one end leaves the arrow as plain ink; his next strokes carry it without its connector notes.
