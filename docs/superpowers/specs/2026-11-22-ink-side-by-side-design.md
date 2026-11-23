# Ink side by side: the iPad's own ink beside the web board's

Status: built for bead context-grabber-vabk (story 1209). Asked for by Igor on 2026-11-22 at 21:38, via Larry.

## Summary

A debug screen on the iPad that splits down the middle. The left half is the app's own ink, a plain PencilKit canvas.
The right half is Larry's web board, the Cockpit's */ink* page, open on its *scratch* board. Igor draws on both,
one after the other or with a hand on each, and feels which ink keeps up with the Pencil. Each half shows a small
number in its corner: how long its last stroke took from touching down to the next frame, and the median so far.

It is an A/B tool and nothing else. The board itself is untouched: it keeps drawing with PencilKit exactly as it
does today, and nothing about the web board changes either.

## Goals

- Feel the two inks next to each other on the same iPad, at the same moment, under the same Pencil.
- Put a number beside the feel, the same kind of number on both sides, so a difference that is felt can be checked.
- Leave each sample in the session log, so a pulled log can be compared after the fact.

## Non-goals

- No change to how the board draws. Moving the board to the web's ink, or the web's to PencilKit, is a later
  decision this tool informs.
- Not a benchmark. The number is a guide (see *What the number means*), not a measurement of light leaving the glass.
- Not on the iPhone, which only looks at boards.
- No saving: the left half's ink is gone when the screen closes. The right half is the web board's own *scratch*
  board, which keeps what is drawn on it as the web board always does.

## What Igor sees

- **Where:** the home screen's Settings → *About and diagnostics* → **Ink side by side**. The row is on the iPad and
  the Mac, never on the iPhone.
- **The screen:** two halves of equal width with a thin line between them. The left is headed *iPad ink
  (PencilKit)*, the right *Web board (/ink)*. Each half fills the height under the bar.
- **The left half** draws with a black pen under the Pencil or a finger. A **Clear** button in the bar empties it.
- **The right half** is the Cockpit's */ink* page on its *scratch* board, the same page as in Safari, with its own
  tools. If the Cockpit can't be reached, the half shows the page's own error and the left half still works.
- **The readout:** each half's top corner shows its numbers as `last 18 ms · median 21 ms · 12 strokes`, and
  *Draw to measure* before the first stroke. The numbers update with each stroke. Leaving the screen and coming back
  starts both counts again.
- **The log:** each stroke on either side adds an `ink_side_by_side` event: which side, the milliseconds, the
  running median and the count.

## What the number means (and doesn't)

Both sides measure the same span: **from the moment the pen touched down to the start of the next frame the
display draws**. That is the earliest frame the new stroke could appear in.

- **Left (PencilKit):** the touch's own timestamp, to the first display-link tick after it.
- **Right (web):** the pointer event's own timestamp, to the first animation frame after it.

Each side compares two times on one clock, so each number is sound on its own terms. They differ in what they
can't see:

- Neither number sees the pixels. A side that misses the next frame and draws the stroke one or two frames later
  shows the same number as one that doesn't. The feel is the real test; the number checks the gross difference
  (a touch that waits for the system, a page that is busy).
- The web side's touch timestamp is taken after the touch has crossed into the web page's process, so whatever
  WebKit adds getting it there is counted. The PencilKit side's isn't, so the web side's number includes a cost the
  native side's doesn't have to pay. That is part of the difference being measured.
- PencilKit predicts the Pencil's path ahead of the touches, and the web page can't. That shows in the feel, never
  in the number.
- A stroke that takes longer than a second to reach a frame, or a number below zero, is a fault in the measuring,
  not a stroke: it is dropped and counted in the log as dropped.

## Acceptance criteria

- On the iPad, Settings → *Ink side by side* opens the two halves side by side. The left draws, and the right shows
  the web board's *scratch* board, which draws too.
- Each stroke on either half updates that half's readout, `last … ms · median … ms · n strokes`, and adds one
  `ink_side_by_side` event to the log, naming the side.
- With the Cockpit unreachable, the right half shows the page's error, and the left still draws and measures.
- Closing the screen and opening it again starts both readouts at *Draw to measure*.
- The iPhone's Settings has no *Ink side by side* row.
- The board's own drawing behaves exactly as before.
