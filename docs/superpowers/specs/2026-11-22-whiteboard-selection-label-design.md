# What's selected: a label on the selection

Issue [#1045](https://github.com/idvorkin/context-grabber/issues/1045). Story 1108
([gestures](../../stories/10-whiteboard-gestures.md)). Related: #947 (selecting groups) and #1005 (the top bar's
labels, whose one-word-plus-what-it-does naming this follows).

## The idea in one line

When something on the board is selected, a small label beside it says what it is and what applies to it: *Text · tap
to reword*, *Ink · To text*, *Connector · follows its two ends*.

## Why

The board shows letters that look alike but are different things: Igor's handwriting (plain ink), a kept text of
Larry's (one thing, reworded with a tap), a group of Larry's (moves as one), a word of Igor's that a connector made one
thing, and a connector. A partial erase quietly turns a text or a group back into plain ink that still looks the same.
Nothing on screen tells them apart, so Igor finds out what he picked by trying something.

What the iPad's log shows (2026-11-17, one board): four rewords opened on three of Larry's texts within ten seconds;
the first three closed unchanged within one to three seconds, and only the fourth was reworded. Opening a text to see
whether it is the one he meant is the hunting this label is for. On 2026-11-21 a To text went off on the whole board
(664 strokes, a 1.3 MB picture) three seconds after the last selection the board logged was empty: nothing on screen
said how much was selected.

## What Igor sees

- **Whenever the selection holds something** on a board drawn on here, a small label shows just above it (below it
  when there is no room above), over the board: it is in no picture of the board, takes no touch (the Pencil and a
  finger go through it to the board as if it weren't there) and moves with the selection as the board scrolls or
  zooms. It goes when the selection goes.
- **What it says**, first match wins:
  - Only connectors: *Connector · follows its two ends* (*2 connectors · follow their ends* for more).
  - A drawn arrow that Connect can join: *Arrow · Connect* (the Connect button shows beside it as before).
  - All of one kept text: *Text · tap to reword*. Part of one: *Part of a text · erasing it leaves ink*.
  - All of one group (Larry's, or a word of Igor's a connector made one thing): *Group · moves as one*. Part of one:
    *Part of a group · erasing it leaves ink*.
  - A text or group a connector ends on adds *· a connector follows it*.
  - Only plain ink: *Ink · To text*.
  - Several texts and groups, no plain ink: *2 things · move together* (the count is how many).
  - Plain ink with texts, groups or connectors: *Ink and a text*, *Ink and a group*, *Ink and 3 things*.
- **It says it again after a change**: after the eraser takes part of a selected text (it is ink now), after an undo
  or redo, after a fold, and after Larry's change, the label says what the selection is then.
- **Not shown** on a look-only board, beside a paste (it has its own Delete), or while a text is open for rewording.
- **The buttons don't change.** To text and Connect show exactly as before; the label only names them.
- **VoiceOver** reads it as *Selected: Text, tap to reword*, and it is reachable as one element.
- **The board's ? sheet** has a row for it: *Select something: a label says what it is and what applies.*
- **The session log** says what each new label said: its kind, how many strokes, and the words.

## Acceptance criteria

- A lasso round Igor's handwriting shows *Ink · To text* above it, and To text beside it as before.
- A selected kept text shows *Text · tap to reword*; erasing part of it and selecting the rest shows *Ink · To text*;
  Undo, and the label (with the text selected again) says *Text · tap to reword*.
- A selected connector shows *Connector · follows its two ends*; a word a connector ends on, selected, says *Group ·
  moves as one · a connector follows it*.
- The first Pencil stroke after a selection, even starting on the label, draws; the label never takes a tap.
- The label is never in the picture Larry gets.

## Not in this step

- The comparison on Igor's iPad that #1045 asks for (two similar labels to edit, a connected word to move, its section
  to fold, part of its end to erase and undo; first-action accuracy, recovery taps, accidental changes). It needs the
  build on the iPad and Igor's hand; the log's label events are there to count from.
- Changing which buttons show (To text on a kept text, a Reword button on the selection): the label only names what is
  there today. Whether to add them is a decision after the trial.
- A label for a tap that opens a text (the reword field already shows the words) or for Larry's marks (Keep and
  Dismiss already show).
