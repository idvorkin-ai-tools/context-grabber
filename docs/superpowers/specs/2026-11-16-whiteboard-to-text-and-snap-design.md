# Handwriting to text, and shapes that snap

Status: draft for Igor, 2026-11-16 (stories 920–925). Two things Larry's web board `/ink` already does (cockpit
FEATURES.md, *Ink*; the web board's stories in cockpit `docs/stories/04-notes-chat.md`, *Handwriting to text* and
*Shape cleanup*), brought to the board on paper so the two boards behave alike.

## The idea in one line

Circle some handwriting and tap **To text**: the words take the ink's place as typed text. Draw a line, a box or an
ellipse and hold the Pencil still at its end: it snaps clean.

## Why

- Igor writes on the board and sometimes wants the words typed: to read them back, for Larry, or to tidy a page. The
  web board has had this since cockpit-cah; the iPad didn't.
- A hand-drawn box or line is wobbly. The web board cleans one up when he holds the pen still at its end, and only
  then, so ordinary writing never changes under him.

## What Igor sees

### To text

- **To text lives in the hold menu, and only there** (stories 1309, 1310; #1386; Igor, 2026-11-24: "To text only in
  the long-press menu"). A finger held still on ink, on a board drawn on here, offers *To text* right after *Select*:
  on a word of his, on a group, and on a header's row. It never shows on its own beside a selection, so a tap or a
  lasso brings up nothing over the board. The rule is the shared board core's, so the web board's long-press menu
  offers it the same way.
- *To text* from the hold menu takes the thing under the finger, as *Select* would pick it, and reads it.
- A lasso round ink names it *Ink · hold for To text* in the selection's label, pointing at where To text is.
- Choosing it sends a picture of just that ink (cropped to it, on white, nothing else of the board in it) to the Cockpit,
  which reads the handwriting. While it reads, *Reading…* shows beside that ink (a status, not a button), and To text can't start again until it answers: the hold menu leaves its row out meanwhile.
- The words come back and take the ink's place: typed in the plain (print) lettering, in the ink's colour, at its top
  left, sized to the lines he wrote, one typed line per written line. The ink goes. It is a kept text, like one of
  Larry's: one thing on the board, moved and erased whole, and Larry gets it back as text under its id.
- One Undo brings the ink back and takes the text away; Redo does it again.
- If the Cockpit can't read it (it's away, it refuses, the model fails), the ink stays exactly as it was and a
  copyable problem says why, naming the board, the Cockpit's status and its reason.
- If there's no writing in the picture, the ink stays and the board's note says *No writing found there*.
- If the writing is more than one text holds (500 characters, the Cockpit's own cap), the ink stays and the note says
  *Too much writing for one text (500 characters): select less*.

### Shapes that snap

- He draws a stroke and holds the Pencil still at its end for about half a second (it moves less than 5 board
  points). When he lifts, a stroke that is nearly a straight line, a rectangle or an ellipse is replaced by a clean one:
  the line from its start to its end; the rectangle square to the page (a tilted one stays ink); the ellipse in the
  stroke's box, starting where he started.
- The same stroke lifted without the hold never snaps, and nor does ordinary writing.
- A stroke smaller than 30 board points never snaps. A closed shape must close (its ends within a fifth of its size)
  and have some body; a rectangle must reach its four corners. The thresholds are the web board's: a line within 6 % of
  its length, a rectangle within 7 % of its size, an ellipse within 10 %.
- The clean shape keeps his pen: its ink, colour and width, drawn evenly.
- One Undo gives his raw stroke back; a second takes the stroke away, as for any stroke.
- Only the Pencil (or a finger while fingers draw) with a drawing tool snaps: not the eraser, not the lasso.

## Acceptance criteria

- To text on a selection of handwriting replaces it with a kept text of the Cockpit's words, one undo.
- A failure leaves the ink and shows a copyable problem; no writing or too much writing leaves the ink and says so.
- A held stroke that is nearly a line, rectangle or ellipse snaps on lift, one undo back to the raw ink; without the
  hold nothing snaps.

## Not in this step

- Editing the words of a kept text in place, and the snapped shape showing clean while the Pencil is still down: both
  came next, in [Rewording a kept text, and a snap you see before you lift](2026-11-17-whiteboard-reword-and-live-snap-design.md).
- Making room below when the text is taller than the ink it replaced: the text is sized to the ink's lines, so it
  fits in nearly every case.
