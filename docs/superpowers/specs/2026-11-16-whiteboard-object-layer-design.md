# Whiteboard: objects over the ink, making room, and reflow

Igor, on the board, 2026-11-16: "Larry on [the board] is just ink layer… also object model", "did you build push
content down properly", "Larry, can it push stuff down", then: "Have insert space be smart, have Fable design it. So
like how much space required, think about the space existing @ margin time, some object model on top of the ink layer,
the reflow of content, this is an important design." The same morning a paste landed on his writing (he had tapped
Paste by accident: "Nope").

Builds on [the whiteboard](2026-11-01-whiteboard-design.md), [ghosts and shapes](2026-11-01-whiteboard-shapes-design.md),
[paste](2026-11-02-whiteboard-paste-design.md) and [the conversation strip](2026-11-12-whiteboard-conversation-design.md).
**This is a design for Igor to mark up. Nothing here is built.** Stories go in
[10-whiteboard.md](../../stories/10-whiteboard.md) with each slice that is.

## The idea in one line

A kept mark or a paste stays **one thing** Igor can pick up, change or remove, and anything that needs room **finds
clear paper or pushes the ink below it down**, so nothing ever lands on his writing.

## What is wrong today

- **Everything is flat ink.** A kept label is a few dozen letter outlines. It can't be moved as one thing, reworded or
  removed in one go; the eraser takes it a letter's edge at a time.
- **Things land on his writing.** A paste goes to the middle of the screen whatever is there. Larry's marks go where
  his picture was, and he answers minutes later, after Igor has written on. Larry's only defence is a rule in his own
  notes to leave a line clear, and a guess at where clear paper is.
- **Larry can only squeeze into gaps.** A diagram that needs ten lines has nowhere to go on a full page.
- **Ink has already moved on its own once and split a kept label** (#624). Whatever moves ink must know what belongs
  together.

## What this reverses

The whiteboard's non-goals say "no shapes palette, layers, text boxes", and paste's say no "movable text blocks" and no
editing. This reverses the second and part of the first: a paste and a kept mark become movable, editable, deletable
things. It does **not** add a shapes palette, a text tool or layers for Igor to manage. The Pencil and the tool picker
stay the whole drawing interface; objects come only from a paste or a Keep.

## Goals

- A kept mark and a paste are each one object: select, move, edit its words, delete.
- Nothing Larry, Claude or a paste adds covers ink that was there first, unless Larry meant it to (a circle round a word).
- Larry can ask for room, and the board works out how much to open from what the reply needs and what is already blank.
- Igor can open and close room by hand.
- Moving ink is one undo, never scales a stroke, never splits a line of writing or an object.
- Every board that exists opens unchanged, and an older build still opens every board.

## Non-goals

- Igor's own handwriting as objects (recognising his lines, paragraphs or diagrams). His ink is ink. Reflow moves it
  by where it sits, never by what it means.
- Reshaping: no resize handles, no rotating, no dragging an arrow's end. Move, reword, delete.
- Arrows that stay attached to what they point at when one end moves.
- Sideways reflow or columns. Room opens across the whole page width, downward only.
- Larry moving, editing or deleting objects. He proposes marks and room; Igor's tap decides. (His protocol leaves the
  door open; see *Protocol*.)
- Two devices drawing one board. Unchanged.

## The object model

### What an object is

An object is **a set of ink strokes that belong together, plus what made them**: its kind (label, arrow, line, box,
circle, arc, curve, pasted text), its words if it has any, its look (pen, colour, lettering, letter size), who made it
(Larry, Claude, a paste) and, for a mark, which reply it came from.

The strokes are ordinary ink in the drawing. The object is the note that says "these strokes are one label that reads
*try the other order*". So an object is in every picture, in the strokes Larry gets, in the saved board and on the
look-only phone exactly as ink is today, with no extra work.

### How things become objects

- **Keep** on a ghost makes the ink it makes today, and that ink is one object. One undo still takes it back whole.
- **A paste** makes one object for the whole block of text, not one per line.
- **Copied strokes pasted with ⌘V** stay plain ink, as they were ink when copied.
- **Igor's own strokes are never objects.**
- A ghost is not an object. It is still nothing until kept.

### Select, move, edit, delete

- **A finger tap on an object selects it**: a thin outline round it and a small row of buttons beside it, placed like
  Keep and Dismiss are today (wholly on screen, following the object as the board moves). The Pencil never selects; it
  draws, through an object as through anything.
- **The buttons:** **Edit** (objects with words), **Delete**, and a grip to drag. A tap elsewhere, or starting to draw,
  puts them away and changes nothing.
- **Move:** dragging the selected object with a finger moves it. It lands where it is dropped, even on ink: Igor put it
  there. One undo puts it back.
- **Edit:** the words open in a small text field over the board with the keyboard. Done redraws the object in place
  with the same look, growing down and to the right from its top-left corner. If the new words need more height than
  the old and ink sits below, the object makes room for itself (below). Paste's caps (500 characters, 40 lines) hold.
  Emptying the words deletes the object.
- **Delete** removes every stroke of it. One undo brings it back, still an object.
- **A just-pasted object lands selected**, so a paste Igor didn't mean is one tap on Delete (or one undo) away, and a
  paste in the wrong place is one drag.

### Objects and the Pencil's own tools

The ink is real ink, so the eraser and the lasso can reach it. The rules:

- **The lasso moves an object's strokes**: if it took all of them, the object moved and stays an object. If it took
  some, see the next rule.
- **An object that loses or is parted from some of its strokes dissolves into plain ink**: the pixel eraser rubbing
  out half a letter, the stroke eraser taking one, the lasso dragging part away. What is left on the board is exactly
  what he sees, as ink. Nothing is deleted on his behalf and nothing snaps back. Undo of that erase restores the object.
- **Drawing over an object** doesn't change it. His stroke is his ink, on top.

Trade-off: dissolving is blunt. Cross out one letter of a pasted paragraph and the paragraph can no longer be edited
as text. The alternative, an eraser that refuses objects or takes them whole, makes the eraser behave two ways on ink
that looks the same. Dissolving keeps "what you see is ink" true.

### Where objects are kept: the choice

| | A. Ink plus a note beside it (proposed) | B. PaperKit's own text boxes and shapes | C. A separate layer the app draws |
|---|---|---|---|
| What an object is | Strokes in the drawing, and a note kept with the board saying which strokes are which object | A system element in the board's file | Not ink: drawn by the app over the paper, as ghosts are |
| Saved file | Unchanged: strokes | Changes to the system's richer format | Unchanged, plus the layer |
| Older builds, look-only devices | See everything, as ink | Can't open the board | See no objects at all until updated |
| Larry's picture and strokes | Unchanged | Must learn non-stroke elements | Must be composited in; kept marks stop being strokes |
| Eraser, lasso, undo | Work as on any ink; rules above for tearing | The system's own, for free | Don't reach objects at all |
| Editing text | Redraw the strokes from the words | The system's editor, for free | Redraw the layer |
| Cost | We own selection and the tearing rules | Reverses "what's saved doesn't change"; one-way migration; system UI we don't control on the board | Two kinds of mark that look alike and behave differently |

**Proposed: A.** It is the only one where every promise already made about ink (the picture, the strokes, sync, older
builds, the phone) stays true without touching it. If the note is lost or unreadable the board is still complete: every
object is simply ink again.

The note travels with the board to other devices. A device that doesn't understand it shows ink, and since only the
device that made a board draws on it, a stale note can't be written back over a newer drawing.

## Making room (insert-space)

"Room" is blank paper opened at a line across the page by moving everything below that line down.

### Who asks

1. **Larry**, as part of a reply: a new kind of mark that says *open room here for the marks in this reply*.
2. **Igor**, by hand, anywhere (below).
3. **The board itself**, when something must land and what's under it is ink it shouldn't cover: a paste, an edited
   object that grew, and a kept mark that has ended up on ink Larry never saw.

### How much: the sum

For any of the three, at the moment the room is opened (never at the moment the picture was taken):

1. **The cut.** Start from the asked-for height on the page. Move it to the nearest **clear line**: a horizontal line
   that crosses no ink and no object. Look up and down within two lines of writing (80 points); if there is none, go
   down to the first clear line below. Nothing is ever split: by construction no stroke crosses the cut.
2. **What is needed.** The height of what is going in, measured by the board from the real thing: the marks' own
   outlines as the board draws them (its letters, not an estimate of them), or the pasted block as laid out. Plus half
   a line (20 points) of air above and below.
3. **What is already there.** The blank band the cut sits in: from the lowest ink above it to the highest ink below.
4. **The push.** Needed minus already there, never less than zero, rounded up to a whole line (40 points) so ruled
   writing stays on the rules. Zero means nothing moves and the reply simply sits in the gap.
5. **Blank paper further down takes up the push.** Walking down from the cut, each blank band taller than two lines
   gives up what it has beyond two lines, and the ink below it moves that much less. Once the push is used up, nothing
   below moves at all. So opening room near the top of a ten-page board usually moves a few lines, not ten pages.

"Smart" means steps 2 to 5: Larry never has to guess a height, and existing blank paper is spent before ink is moved.

Trade-off in step 5: Igor's deliberate big gaps shrink toward two lines when room is opened above them. The
alternative, pushing everything rigidly, keeps his spacing and moves every page. Proposed: spend the gaps; one undo
restores them.

### Before the push: clear paper that is already there

A push is the last resort. In order:

1. **In place.** If what is landing covers no ink where it was asked to go, it goes there. Most of Larry's short
   labels beside a word do.
2. **Nearby clear paper, for a paste only.** A paste has no place it must be, so it takes the clear patch nearest the
   middle of the screen that holds it whole, on screen. Larry's marks are not moved sideways by the board: he placed
   them beside the thing they name, and moving one breaks that.
3. **A push**, by the sum above.

### Larry's room, as Igor sees it

Nothing Larry sends changes the board until Igor says so. That holds.

- A reply that asks for room shows a **faint dashed line across the page at the cut** with a small tag, *Make room · 6
  lines*, in Larry's colour, and his marks for that room as ghosts where they would sit, over whatever is there now.
- **A finger tap on the tag offers Make room and Dismiss.**
  - **Make room** opens it. The ink below slides down, the ghosts are now on blank paper, and each is kept or
    dismissed one at a time as today. Opening is one step: one undo closes it and the ghosts are back over the ink.
  - **Dismiss** removes the tag and that room's ghosts. They don't come back.
- **Keep on one of those ghosts before making room** makes the room first, in the same step: one undo takes back both.
- If the sum comes to zero (the gap was already big enough) there is no tag and no line. The marks are ordinary ghosts.
- Room that was opened and then left empty (every ghost dismissed) stays. It's blank paper; Igor can close it by hand
  or undo.

### A late reply

Larry answers a picture minutes old. Two things may have happened since.

- **The board was pushed.** Every push is remembered (where, how far, when). A mark, a cut or a ghost placed by an
  older picture is carried through every push since that picture, so it still sits on the ink it was drawn beside.
  Unkept ghosts on the board slide with the ink in a push for the same reason.
- **Igor wrote where the reply lands.** When a ghost of Larry's covers ink drawn **after** his picture was taken, ink
  he couldn't have seen, Keep makes room for it: the newer ink moves down, by the sum above, in the same step as the
  keep. Ink that was in his picture is never pushed this way: if he drew over it, he meant to.

### Igor's room, by hand

What a finger does on paper is still unsettled in the main spec, so this is a proposal to try on the iPad, not a
claim.

- **Proposed:** a finger pressed and held in the page's left margin shows a line across the page at the nearest clear
  line, with a grip. Dragging the grip **down** opens room as it goes, a line at a time; dragging **up** closes blank
  paper and stops at the first ink. Lifting ends it. The whole drag is one undo.
- **Fallback if the margin hold fights with scrolling:** *Insert space* in the Board menu, then a tap where.
- By hand there is no sum: the room is as tall as the drag. Step 5 still applies (blank bands below take it up).

## Reflow rules

**What moves**

- Whole strokes and whole objects, by sliding straight down (or up, when room is closed). Never scaled, rotated or
  moved sideways, and each keeps its place relative to its neighbours between two blank bands.
- Unkept ghosts and a waiting *Make room* tag below the cut, with the ink.
- The view, when the cut is above what is on screen: the paper under his eyes stays under his eyes.
- An object counts as a solid block when finding clear lines, so a cut never passes through one.

**What never moves**

- Anything above the cut.
- Anything below a blank band that took up the whole push.
- Page lines, the grid and ruled lines. They are paper.
- Anything, while the Pencil is down. A push that is due waits for the lift, and a push Igor didn't tap for never
  happens at all.
- Anything on a look-only board.
- A stroke under way. (A push needs a tap or a paste, and both need the Pencil up.)

**Pages**

- Ink may cross a page's end today, and pushed ink may too. Nothing is held back to keep a page whole.
- A push that carries ink past the last page brings the pages it needs, with the blank one below, in the same undo
  step, as a kept mark does today.
- Closing room never removes a page while the board is open, as erasing doesn't.
- **Trade-off, named:** each page is ruled from its own top and a page is 26½ lines tall, so writing pushed across a
  page's end sits half a line off the rules on the next page. Pushing by whole lines keeps it right within a page
  only. Fixing it means either ruling the column continuously (changes a settled choice) or adding half a line to ink
  that crosses a page's end (lines of writing drift apart). Proposed: live with it in the first build and see if Igor
  notices.
- **Trade-off, named:** a cut is the full width of the page. A tall diagram beside a column of notes has no clear line
  through it, so room asked for beside it opens below it. Column-aware reflow is not proposed.

**Undo**

One push, with everything it carried (the pages, the keep or paste that caused it), is one undo and one redo. Undo
doesn't outlive the board, as today.

## Paste, after this

- A paste lands as one object, **in clear paper**: the clear patch nearest the middle of the screen, or, with none big
  enough on screen, in room opened at the clear line nearest the middle of the screen.
- It lands selected, with Delete beside it.
- Everything else in the paste spec holds: the button, ⌘V, the caps, the bar's words, one undo for the whole paste
  (now including any push).

| Where a paste goes | For | Against |
|---|---|---|
| Middle of the screen, always (today) | Predictable | Lands on his writing; the bug |
| Clear paper, else make room, lands selected (proposed) | Never covers ink; a mistake is one tap | A paste on a full screen moves ink without asking; undo fixes it |
| Arrives as a ghost, needs Keep | An accidental tap changes nothing | Every deliberate paste costs a second tap |

## Protocol

Three parties change: the app, the Cockpit (which checks and stores Larry's marks) and Larry's whiteboard skill. Each
change is additive, and each side works against an older other side.

### The new mark

In a reply's `shapes`, beside the others:

```json
{"kind": "insert-space", "y": 1840, "h": 520}
```

- `y`: where to cut, in the picture's pixels, like every other mark.
- `h`, optional: the height of the blank band Larry drew into, when he composed the reply on a render of the board
  with that band already opened. The marks between `y` and `y + h` are the room's marks; marks below `y + h` are on
  ink that moved, and the board carries them back to that ink.
- Without `h`: every mark in the reply that starts at or below `y` is one of the room's marks, drawn as if the paper
  below `y` were blank. No mark in that reply can point at ink below the cut.
- Either way `h` is not what the board opens. The board measures the room's marks itself and runs the sum. `h` only
  says how Larry's picture was laid out.
- One per reply to begin with. A second in the same reply is ignored and logged.
- A reply with `insert-space` and no marks for the room opens nothing.

### What the app tells Larry

- **What it can do.** Each picture's message carries `can`, a list of words: `["insert-space", "objects"]`. Larry
  uses `insert-space` only when the picture he is answering says so.
- **Objects, with the strokes.** The strokes that go before every picture gain an `objects` list: for each, an id, its
  kind, its words, who made it, which reply and mark it came from, its box in board points, and the ids of its strokes.
  Larry reads a pasted paragraph as text (the paste spec's "a later change can send the words alongside"), and knows
  which of his marks were kept without inferring it from colour.
- **Moved ink is the same ink.** A stroke's name is made from where its points are, so a pushed stroke gets a new
  name, and today the Cockpit would call everything below a cut erased and drawn again. Each moved stroke therefore
  carries `was`, its name in the last send. The Cockpit counts a stroke with a `was` it knows as neither new nor
  erased, and *new since my last turn* stays honest.
- **Pushes.** The same send carries `pushes` since the last one: where each cut was and how far each band moved. This
  is how a render of an older picture can be lined up with the board now.

### Backward compatibility

| Older side | Newer side | What happens |
|---|---|---|
| Older app | Newer Cockpit and Larry | The picture has no `can`, so Larry never sends `insert-space` and answers as today. If one arrives anyway, the app drops a kind it doesn't know, as it always has, and draws the other marks where they say. |
| Newer app | Older Cockpit | The Cockpit drops fields it doesn't know from messages and strokes, so `can` never reaches Larry and he answers as today. Pushed strokes read as erased and new, which is wrong but harmless, and is the reason the Cockpit goes first. A Cockpit that doesn't know `insert-space` drops that mark and keeps the rest. |
| Newer app and Cockpit | Older skill | Nothing asks for room. Objects, clear-paper paste, room by hand and room for a late reply all work: none needs Larry. |

Build order: Cockpit (accept and store the new kind, pass `can`, `objects`, `was`, `pushes`; allow a room's marks to
sit below the picture's bottom edge by `h`), then the app, then the skill (ask for room instead of squeezing; drop its
leave-a-line-clear rule once the app makes room for late replies).

Claude's fast ghosts don't ask for room in this design. They last 30 seconds and are meant to be small.

### Left open on purpose

Objects have ids Larry can see. Marks that act on them (move this, reword that, delete mine) fit the same pattern as
`insert-space`: a proposal Igor taps to accept. Not designed here.

## Existing boards

- **Nothing is converted.** Every board opens as it does today. Its ink is ink.
- **Marks kept and text pasted before this stay plain ink.** The board never recorded which strokes were which label,
  and guessing from colour would be wrong often enough to matter. Objects exist from the first keep or paste after the
  build.
- **Boards drawn on the old canvas and boards from another device stay look-only.** No objects, no room, no reflow.
- **An older build opening a newer board** sees all of it as ink and ignores the note. Only the device that made a
  board draws on it, so that older build can't change the ink behind the note's back; if a note ever names strokes
  that aren't there, that object is dropped, the ink stays, and the log says so.
- **Stroke names don't change** for ink that hasn't moved, so the Cockpit's history of each board still lines up.

## Test plan

By the test ladder; each slice says which rung it used.

**Host (the bulk: all of this is arithmetic on boxes)**

- Clear lines: found within two lines of the ask; else the first below; never through a stroke's box or an object's.
- The sum: needed, already there, push rounded up to whole lines; zero when the gap is enough.
- Blank bands below take up the push; ink below a band that took all of it has not moved; a band never shrinks under
  two lines.
- A push is a pure slide: every moved stroke keeps its size, and its place relative to its band's others.
- Carrying a mark from an old picture through one, two and overlapping pushes; a mark above every cut doesn't move.
- "Ink Larry couldn't see": a ghost over older ink keeps in place; over newer ink it makes room.
- Objects: all strokes moved together stay one object; any stroke lost or parted dissolves it; undo restores it; an
  unreadable or stale note gives a board of plain ink and no error.
- The mark: with `h`, without `h`, with no room marks, two in one reply, numbers a board can't have.
- The strokes send: `was` on every moved stroke and none other; `objects` matches the board; `can` on the message.
- Paste: clear patch chosen nearest the middle; none on screen makes room; the caps still hold.
- Against a real board's strokes (Igor's densest saved board as a fixture, with his OK): no cut ever lands in a line
  of handwriting. Synthetic boxes will pass where real cursive, with its tall loops, will not.

**Cockpit (its own tests)**: the new kind is kept and checked, an unknown kind is still dropped, `was` suppresses
new and erased, a render lines up across a push.

**Simulator (launch hooks and UI tests against the fake Cockpit)**: a reply with room shows the tag; Make room moves
the ink and one undo restores it; Keep before Make room does both; a paste on a full screen lands on blank paper and
selected; Delete removes it; a finger tap selects a kept label and Edit rewords it; pages are added by a push and
taken back by its undo; the session log says each cut, sum and push in numbers.

**iPad only**: whether a finger hold in the margin can be told from a scroll; how a large push looks (a jump or a
slide) and whether the paper under the Pencil redraws at once; the lasso and both erasers on an object; that kept ink
shows after a push (the "saved and counted but not shown" bug has happened before on paper); a real late reply from
Larry while Igor keeps writing.

## Open questions for Igor

1. **"The space existing @ margin time."** What did you mean? This design read it two ways and used both: the blank
   paper already there *at the moment room is opened* (spent before any ink moves), and the page's *margin* (where
   your finger opens room by hand). If you meant Larry should write in the side margin instead of pushing, that is a
   different design.
2. **Should Larry's room need your tap, or open on its own?** Proposed: a tap (*Make room*), because nothing of his
   changes the board until you say so. The other way is faster and moves your writing while you may be mid-thought.
3. **Should a paste move ink without asking** when the screen is full, or arrive as a ghost you Keep? Proposed: it
   lands in clear paper or makes room, selected, with Delete beside it.
4. **Is "cross out part of an object and it becomes plain ink" right?** The other choice is an eraser that takes the
   whole object, or leaves objects alone.
5. **Should your own writing push Larry's objects out of the way** when you write into one? The bead says "content
   reflows when Igor writes above them". Proposed: not in the first build. Moving things while you write is the
   easiest way to make the board feel haunted; room by hand covers it until we see how often it comes up.

## Smallest first slice

Fixes the stated pain (things landing on ink) and needs no object note, no gesture and no new mark:

1. **The sum and the push**, as host-tested arithmetic: clear lines, needed against already there, whole-line push,
   one undo. No taking-up by blank bands below yet: a rigid push.
2. **Paste lands in clear paper or makes room.** Still plain ink, not yet selected.
3. **Keep makes room when Larry's ghost covers ink newer than his picture.**
4. **`was` on moved strokes, and the Cockpit honouring it**, so the first push doesn't tell Larry the whole page is new.

Then, each its own slice: objects (the note, select, Delete, move, Edit); Larry's `insert-space` with `can`; room by
hand; blank bands taking up the push.
