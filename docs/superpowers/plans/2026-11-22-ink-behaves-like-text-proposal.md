# Ink that behaves like text: what is still to decide

A proposal for Igor, 2026-11-22. Bead context-grabber-0sf.

This is not a spec. Igor makes a pick for each question. Then the object design
([2026-11-16-whiteboard-object-layer-design.md](../specs/2026-11-16-whiteboard-object-layer-design.md), which lands with
PR #1194) and the stories change first, and the code after that.

Principle 5, in Igor's words: "it's actually ink that behaves like text, and it has layers, and it has collapsing and
all that jazz". Bead context-grabber-0sf names the questions this proposal puts to him.

**What is built today.**

- **Pushes.** Every push opens room downward from a clear line, in whole lines. It is rigid: everything below the cut
  moves the same distance, all the way to the end of the board.
- **Folds.** A fold closes up its section and unfolding opens it again.
- **Drops.** A selection, a kept text or ink dropped on writing pushes that writing down in whole lines (story 973;
  story 1172 lands with PR #1217).
- **Erasing.** Erasing a folded section closes the gap it leaves (story 902). Erasing anything else leaves blank paper.
- **The one rule.** Making room follows one rule (story 1148, which lands with PR #1194): Larry's ink never covers
  writing he didn't see, and Igor's newer writing moves down in whole lines.

Each section below can be read on its own and turned into one decision card. Each ends with Igor's pick, which is still
to be filled in.

## 1. Does deleting a line close the gap?

Today a deleted line leaves blank paper. Two things close a gap now:

- erasing a whole folded section (story 902);
- dragging the margin handle up, which closes blank paper only (story 858).

Principle 2 says his ink "moves only to make room". Closing a gap would be the first time his ink moves because
something was taken away.

| | What Igor would feel | Cost | Risk |
|---|---|---|---|
| **A. Never on its own (today)** | The paper stays as he left it; a deleted line leaves a hole, as on real paper. He closes it with the margin handle. | None | It doesn't feel like text, and the hole stays until he deals with it. |
| **B. Offered** | After an erase leaves a blank band of a whole line or more, a faint *Close up* shows in the margin for a few seconds. One tap closes it in whole lines, and one Undo reopens it. | Small: closing blank paper exists already, so this is one chip and its timer. | Another chip on the page. It also shows after he erases a scribble he meant to rewrite. |
| **C. Automatic for a whole row** | Erase every stroke of a row and the ink below slides up in whole lines, as a fold erase does. A partial erase never closes anything. | Medium: the board must tell that a row is now empty, and the erase and the close must be one Undo. | He erases a line to rewrite it and the line below jumps up under his Pencil. It also breaks "moves only to make room". |

**Recommended: B.** It is text-like when he wants it, and nothing moves without his say (principles 1 and 2).

A delete in a change from Larry follows the same pick. Under B, that change offers no chip: Larry closes a gap only by
asking for it.

**Igor's pick:** _pending_

## 2. Does blank paper further down absorb a push?

Today every push is rigid. Open room near the top of a ten-page board and all ten pages move.

The object design already proposes the other way, in *How much: the sum*, step 5: walking down from the cut, each blank
band taller than two lines gives up what it has beyond two lines. The ink below that band then moves that much less.
It names the cost too: gaps he left on purpose shrink toward two lines.

| | What Igor would feel | Cost | Risk |
|---|---|---|---|
| **A. Rigid (today)** | Every gap he left keeps its size. Every push moves everything below it, to the last page. | None | On a long board the far pages shift for a one-line insert. Ink crossing a page's end lands half a line off the rules, on every page below. |
| **B. Absorb, as designed** | Like pressing return above a blank space in a document: only the paragraph between the cut and the next big gap moves. One Undo restores the gaps. | Medium. It is a pure rule in the room code, with host tests. A push becomes several short moves instead of one, and every place that carries a late mark through a push has to follow it. | A space he kept blank to fill later shrinks to two lines when room opens above it. |
| **C. Absorb, but keep big gaps** | As B, except that a blank band of half a page or more is never spent, because he left it on purpose. | Same as B, plus one threshold. | The threshold is a guess. A board of short notes with big gaps between them behaves like A. |

**Recommended: B, for every push alike:** his own room, a paste, a drop, a keep, and a change from Larry (story 1148,
landing with PR #1194, is one rule).

**Igor's pick:** _pending_

## 3. Does a word dragged into a line push the rest of the line?

Today:

- A word slid along its own line moves nothing else (story 969).
- A word dropped onto another line pushes that whole line down in whole lines (story 973; story 1172 lands with PR
  #1217). It never moves the line sideways.

A "word" here is whatever he picked up: a lasso, or the Pencil held on a word (story 859). His loose strokes are
otherwise never one thing by themselves, so "the rest of the line" means his strokes in that row, to the right of where
the word lands.

Any yes (B or C below) reverses four settled rules:

- the non-goal *Sideways reflow or columns*;
- *never moved sideways* in *Reflow rules*;
- story 969;
- *the board never recognises his lines*.

| | What Igor would feel | Cost | Risk |
|---|---|---|---|
| **A. No, the line goes down (today)** | He drops a word into a line and that line moves down below it, whole. It is predictable, but it is not how text inserts. | None | It doesn't feel like text for an edit in the middle of a line. |
| **B. The rest of the row slides right** | The strokes right of the drop slide over by the word's width and a space. If they would leave the page, it falls back to A. | Medium. The board has to find gaps between words in handwriting, which is new; it has only ever found gaps between rows. | Gaps between handwritten words are uneven, so the cut can land inside a word. A diagram that shares the row slides too. |
| **C. True rewrap** | As B, and words that overflow wrap onto the next line and push the paragraph below. This is closest to text. | High. The board needs words and paragraphs, which means guessing at handwriting. | Highest. One drop can move a lot of ink, and a wrong guess scatters his writing. |

**Recommended: A now.** If Igor says he inserts into the middle of lines often, try B behind a setting, with a
session-log line that records each slide so it can be judged on his real boards. C is not proposed.

**Igor's pick:** _pending_

## 4. Do connectors stretch across a cut, or block it?

Today a connector is a stroke, and it counts as ink when the board looks for a clear line. So a tall arrow means there
is no clear line anywhere along its length, and room asked for beside it opens below its bottom end.

In a push, a connector that starts below the cut moves whole. One whose anchored end moved is redrawn (stories
910–916).

The object design says the opposite. A connector "never blocks room": a cut passes through it and it stretches. The
reason: one tall arrow would otherwise stop room opening anywhere along its length.

| | What Igor would feel | Cost | Risk |
|---|---|---|---|
| **A. Block (today)** | Room opens below the arrow, sometimes well below where he asked. | None | One tall arrow beside his notes freezes room-making for that stretch. |
| **B. Stretch, as designed** | Room opens where he asked. The arrow's lower end goes down with the ink below, its upper end stays, and it is redrawn straight between them. A free end rides with the row under it. | Low to medium. Leave connectors out of the clear-line search; redrawing on a move exists already. Moving a free end with its row is new. | A stretched arrow can cross writing that lands in the new room. A plain arrow he drew and never connected still blocks, and the two look alike. |
| **C. Stretch only when both ends are tied** | As B for a connector between two things. One with a free end blocks, as today. | Low | Two rules for things that look the same. |

**Recommended: B.** It is what the design already says, and it keeps "room opens where I asked" true.

**Igor's pick:** _pending_

## 5. Layers: his ink, Larry's, suggestions, hidden

Today the board already knows whose ink is whose: his own, Larry's kept marks and texts, and unkept suggestions
(ghosts). What exists:

- **The *Ask at my pauses* switch** stops his pauses asking Larry or Claude for suggestions (marks story *Turn off
  *Ask at my pauses**, story 351). It is not a hide: Larry's suggestions already showing stay (story 356).
- **Larry can hide strokes and show them again** (edits story *Larry folds ink away and back*). Hidden ink keeps its
  place and moves with a push, and the board ignores it when looking for a clear line.
- **Igor cannot hide anything himself**, except by folding a section.

PR #1194 frames layers as "whose ink it is and whether it shows, not a layers palette".

Folds are the precedent: hiding is how one device shows the board, the saved board stays whole, and Larry gets
everything, with a flag saying what was hidden.

| | What Igor would feel | Cost | Risk |
|---|---|---|---|
| **A. Four switches in the Board menu** | *My ink*, *Larry's*, *Suggestions* and *Hidden*, each shown or hidden. One tap clears Larry away to see his own thinking, or shows only Larry's. It is a view on this device, like a fold. | Medium: per-layer view state, a menu, and a flag in the picture and the export. | Writing on paper where a hidden layer has ink lands on that ink once it is shown again. |
| **B. Two switches and a Hide action** | *Larry's* on or off (his kept ink and his suggestions together), and *Hidden* on or off. A selection gets **Hide**, which puts anything into the hidden layer, his own ink included. | Low to medium | He can't hide only the suggestions; *Ask at my pauses* only stops new ones being asked for. |
| **C. Layers in name only** | No new control. Layers decide colour and what Larry is told. | Low | It doesn't give him "show or hide one", which is what he asked for. |

Whichever he picks, the same three rules apply:

- **Room.** Ink hidden by a view switch still counts as ink for room. Nothing moves when a layer is hidden or shown, so
  showing it again never lands on writing.
  - Ink in the Hidden layer keeps today's rule for Larry's hide: it moves with a push and takes no room.
- **What Larry, the export and the phone see.** The whole board, each stroke's layer named, and what is hidden on
  screen flagged, as for a fold. The phone, which only looks, shows the board with the Hidden layer hidden.
- **Undo.** Showing or hiding a layer is not on the Undo stack, as a fold isn't. Hide on a selection is.

**Recommended: A**, since he named four layers. All four switches share one mechanism, so A costs little more than B.

**Igor's pick:** _pending_

## 6. The non-goals that now contradict the vision

Whatever he picks for 5, two sentences have to change:

- *Non-goals* in [the whiteboard design](../specs/2026-11-01-whiteboard-design.md): "No shapes palette, layers, text
  boxes or templates. The Pencil and the tool picker are the whole drawing interface; pasted text lands as ink, not a
  text box."
- *Non-goals* and *What this reverses* in the object design: "A shapes palette, a text tool or layers. The Pencil and
  the tool picker stay the whole drawing interface", and "The palette, the text tool and layers stay out."

Proposed wording, for both:

> No shapes palette, text tool or templates, and no stack of layers he arranges. The Pencil and the tool picker are the
> whole drawing interface. Text arrives as ink: by a paste, by *To text*, or in Larry's reply, and kept text can be
> reworded. The board has layers by whose ink it is (his own, Larry's, suggestions and hidden), and he shows or hides
> them from the Board menu.

If he picks B or C in question 3, *Sideways reflow or columns* comes out of the object design's non-goals as well.

## Picks that depend on each other

- **1 and 2.** Closing a gap (1) is the same rule as absorbing a push (2), run upward. Pick them together.
- **4.** Question 4 changes the clear-line search that 1, 2 and 3 all use.
- **5 and 2.** Question 5 decides whether hidden ink takes room, which is what a push absorbs into.
- **3.** A yes reverses the *Sideways reflow* non-goal and story 969.
