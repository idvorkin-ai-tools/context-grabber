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

## Vision

Igor, 2026-11-16: "Lets start with vision on top, 1. Thinking Environment, Doc/Whiteboard 2. Collaborative w/Larry 3. All affordnces of heirachical thinking + Whiteboard, and selection"

### 1. A thinking environment: doc and whiteboard in one

A page you think on, not a canvas you fill. It runs down like a document, so there is always more room below and you can open room in the middle of what you already wrote; and it is still a whiteboard, where anything goes anywhere, in your own hand. Nothing is recognised, retyped or snapped to a grid.

Served by: the push, paste landing in clear space, asking for room (margin handle, hold and drag, box), blank paper
absorbing a push, the press-and-hold menu, grid by default, renaming boards, and later ink replay.

### 2. Collaborative with Larry

Larry is on the page with you, not in a chat beside it. He reads your handwriting, answers in marks you keep or dismiss, and asks for room when his answer needs it; nothing of his changes the page until you tap. What he leaves behind you can move, reword or throw away.

Served by: a late reply making room, Larry's *Make room* on a tap, the Cockpit's `insert-space` mark, his shapes
landing as objects, moved ink keeping its name, and the conversation panel that scrolls.

### 3. All the affordances of hierarchical thinking plus a whiteboard, and selection

What an outliner gives typed text, given to ink: headers, sections that fold with + and −, and things that stay grouped. And what a whiteboard needs to make that usable: tap to select a whole thing, then move it, ungroup it or delete it, with the rest of the page flowing around the change.

Igor, the same day: "I think the core idea here is really that ink is a bit like text, and it can kind of reflow if grouped, selected, ungrouped, and collapsed. It's this interesting hybrid."

Served by: objects from kept marks and pastes, partial erase dissolving an object, rewording and grouping, and
headers with collapse and expand. Each is one of the operations text already has:

| What text can do | On the board | Where |
|---|---|---|
| Group | Strokes that belong together become one object: on Keep, on paste, or when he groups a lasso selection | *The object model* |
| Select | A finger tap picks up an object whole | *Select, move, edit, delete* |
| Ungroup | An object goes back to plain ink, by choice or when the eraser parts it | *Objects and the Pencil's own tools* |
| Move | A selected object is dragged; ink below a line slides as a block | *Select, move…*, *Reflow rules* |
| Make room | A line break: room opens and everything below moves down | *Making room* |
| Collapse and expand | A section tucks under its header and comes back | *Outlining with ink* |

It stays ink throughout: nothing is recognised, retyped or snapped to a grid, and a lost note leaves a complete
board.

## Features to build

Igor, 2026-11-16: "I think we have a bunch of features we want to figure out that we can prioritize into features and
get building." Everything raised that morning, one row per feature, each small enough for one PR, in the order
proposed. *Now*, *Next* and *Later* are a recommendation for Igor to change on the review page. The first three and
the press-and-hold menu are their own small fixes with their own beads and specs; they are listed so the whole
morning is in one place.

| # | Pillar | Feature | What it is | Needs | Proposed | Bead |
|---|---|---|---|---|---|---|
| 1 | 1 | Grid on by default | A new board opens with grid lines. | none | Now | `context-grabber-73u` |
| 2 | 1 | Rename boards | Change a board's name from the list or the board. | none | Now | `context-grabber-77a` |
| 3 | 2 | Chat scrolls, not grows | The open conversation panel keeps its size and scrolls inside. | none | Now | `context-grabber-97s` |
| 4 | 1 | The push | The arithmetic under everything else: find a clear line, slide the ink below it down by whole lines, one undo. Nothing visible on its own. | none | Now | `context-grabber-2q4` |
| 5 | 2 | Moved ink keeps its name (`was`) | A pushed stroke tells the Cockpit what it was called, so Larry isn't told the whole page is new. App and Cockpit. | 4 | Now | `context-grabber-2q4` |
| 6 | 1 | Paste lands in clear space | A paste goes to clear paper on screen, or makes room. Never on ink. | 4 | Now | `context-grabber-2q4` |
| 7 | 2 | A late reply makes room | Keep on a mark of Larry's that sits on writing newer than his picture moves that writing down. | 4 | Now | `context-grabber-2q4` |
| 8 | 1 | Press-and-hold menu | A finger hold on the paper brings up a small menu. First items: Paste, Insert space. | none | Now | `context-grabber-y4y` |
| 9 | 1 | Ask for room: left-margin handle | Hold in the left margin, drag down to open room, up to close blank paper. | 4 | Now | `context-grabber-2q4` |
| 10 | 1 | Ask for room: hold, Insert space, drag | The same drag, started from the press-and-hold menu anywhere on the page. | 4, 8 | Next | `context-grabber-2q4` |
| 11 | 1 | Ask for room: draw a box | Scribe-style: drag a rectangle and that much room opens. The fallback if a finger hold can't be told from a pan. | 4 | Later | `context-grabber-2q4` |
| 12 | 3 | Objects from kept marks and pastes | A kept mark or a paste is one thing: tap to select, drag to move, Delete. A paste lands selected. | none | Next | `context-grabber-2q4` |
| 13 | 2 | Larry's shapes land as objects | Every label, box, circle and arrow he sends is its own object when kept, and he reads each back with its words. | 12 | Next | `context-grabber-2q4` |
| 14 | 3 | Partial erase dissolves an object | Rub out part of an object and what is left is plain ink. Also the Ungroup button. | 12 | Next | `context-grabber-2q4` |
| 15 | 3 | Reword an object; group your own ink | Edit redraws a label or paste from new words. Group makes a lasso selection one object. | 12, 4 | Later | `context-grabber-2q4` |
| 16 | 2 | Cockpit: the insert-space mark | The Cockpit accepts and stores the new mark kind and passes what the app can do to Larry. Must ship before Larry uses it. | 5 | Next | `context-grabber-2q4` |
| 17 | 2 | Larry's Make room, on your tap | His reply asks for room; a dashed line and a tag show; your tap opens it. Then his skill learns to ask. | 4, 16 | Next | `context-grabber-2q4` |
| 18 | 1 | Blank paper absorbs a push | Blank bands below give up their extra lines, so room opened at the top moves a few lines, not every page. | 4 | Later | `context-grabber-2q4` |
| 19 | 3 | Headers and collapse / expand | Mark a row as a header; − folds its section, + opens it; Fold all. | 4, 12 | Later | `context-grabber-2q4` |
| 20 | 1 | Audio-synced ink replay | Notability-style: play a board back stroke by stroke with what was said. Two readings, to be settled: the ink redraws in time with the sound, or a transcript is written out. Every stroke already records when it was drawn, so redrawing without sound is the cheap half. | none | Later | none yet |

- **Pillar** is which part of the *Vision* a row serves: 1 thinking environment, 2 with Larry, 3 hierarchy and
  selection.
- **The push (4) is the root.** Six rows need it and it shows nothing by itself, so it ships inside the first feature
  that uses it (paste lands in clear space) rather than alone.
- **Rows 1 to 3 and 8 need nothing here** and can go in any order, today.
- **The Cockpit goes before Larry** (16 before 17), and `was` (5) before either, for the reasons under *Backward
  compatibility*.
- **Audio-synced ink replay (20)** is not designed in this document.
- **Reading his handwriting** (search, *Make text*) is discussed under *Technical: object types* and is not a row
  yet.

### Prior art: ink that behaves like text

From a separate survey, 2026-11-16. **✓** the linked source says it does; **✗** the source says it doesn't; **?** not
found or not verified; **–** doesn't apply. A **?** is not a no.

| App | Group | Reflow | Insert space | Headers / collapse | Audio sync | Note |
|---|---|---|---|---|---|---|
| [MyScript Notes (was Nebo)](https://help.myscript.com/raw/notes/create-content/adjust-zoom-and-space.md) | ✓ | ✓ | ✓ | heading ✓ (2016), collapse ? | ? | Handwriting reflows in its Document mode; a two-finger long-press adjusts space; underline makes a heading (a 2016 review only). |
| [OneNote](https://support.microsoft.com/en-us/OneNote/onenote-help-and-learning/create-an-outline-to-structure-notes) | ✓ | ? | ✓ | collapse ✓, typed outlines | ✓ | Insert Space, lasso, Ink to Text; collapses typed outlines; playback highlights the notes taken at that moment. |
| [Microsoft Journal](https://support.microsoft.com/en-US/journal/selecting-ink-and-actions) | ✓ | ? | ? | heading ✓, collapse ? | ? | Repeated taps widen a selection from word to line to paragraph to page; a recognised heading gets a Cue that selects its section. |
| [Apple Notes (iPadOS)](https://support.apple.com/en-asia/guide/ipad/draw-or-write-ipada87a6078/16.0/ipados) | ✓ | ? | ✓ | ? for ink | ? | Smart Selection, Insert Space Above, scratch to delete; its collapsible headers are for typed text only. |
| [Notability](https://intercom.help/notability/en-us/articles/16300122-recording-and-playing-audio) | ? | ? | ? | none | ✓ | Tap a word or sketch during playback to hear that moment. No outlining. |
| [Goodnotes 6](https://goodnotes.com/features/audio-recording) | ? | ? | ? | ? | ✓ | Tap ink to jump the audio; Real-time reveal redraws the ink in time with it (from a search snippet; the help page would not load). |
| [Kindle Scribe](https://androidauthority.com/kindle-scribe-note-taking-3330757) | ✓ | ? | ✗ (2023) | ? | ? | Lasso move, cut, copy, resize. The 2023 review found no insert space; Igor uses one on his today, so this cell is out of date. |
| [reMarkable](https://support.remarkable.com/articles/Knowledge/Release-notes-overview) | ✓ | ? | ? | ? | ? | Selection handles, handwriting conversion. |
| [Samsung Notes](https://samsung.com/us/support/answer/ANS00087287/) | ? | ? | ? | ? | ✓ | Highlights the writing as the audio plays; tap handwriting to play from there. |
| [Livescribe pen](https://livescribe.helpscoutdocs.com/article/837-83252) | – | – | – | – | ✓ | Tap ink on paper to play from that moment. |
| [Tivoli (PARC, 1997)](https://chunk.cc.gatech.edu/AY2013/cs4470_fall/readings/moran-tivoli.pdf) | ✓ | ✓ | ✓ | ✓ | – | A wedge gesture opens space in a handwritten list; structural grouping; collapsible annotations. Outline structure was built, then switched off: users only made lists. |
| [Flatland (PARC, 1999)](https://faculty.cc.gatech.edu/~keith/pubs/flatland-chi99.pdf) | ✓ | ? | – | – | time slider | Strokes fall into segments on their own; behaviours attach to a segment; history replays. |
| [Dynomite (FXPAL, 1997)](https://chi1997.acm.org/proceedings/paper/ldw.html) | ✓ | – | – | – | ✓ | An ink and audio notebook that keeps the audio around highlighted passages. |

InkSeine (2007) is ink-driven search, not layout, and is left out.

**What is new here**

- **The combination, on raw ink, on an open page.** No shipping app found puts grouping, reflow, insert space and collapsible headers together on handwriting that stays handwriting. MyScript Notes needs its Document mode; OneNote collapses typed outlines only.
- **Collapsing under a handwritten header.** Journal recognises headings and no collapse was found; Tivoli had it and switched it off.
- **Room that pushes ink without converting it.** Tivoli did it on a 1990s wall board; no current iPad app was found doing it.

**Worth stealing**

- **Tivoli's wedge and pigtail.** A drawn wedge opens space where it points and a pigtail deletes, and lists rearrange by bumping an item into place. A Pencil gesture for room that needs no menu and no finger.
- **Journal's widening tap and heading Cue.** Tap again to widen a selection from word to line to paragraph; a mark beside a heading selects its whole section. The Cue maps straight onto the − in the margin.
- **Goodnotes' real-time reveal.** Dim the strokes not yet played and reveal them in time with the sound. With Flatland's idea of strokes falling into segments on their own, it also hints at grouping without a lasso.

**Two things Igor said that the survey could not pin down**, both now open questions: which "Outlining" he meant
(classic OneNote's + and − outlining, or the iPad app named Outline), and whether replay means the ink redrawing in
time with the sound or a written transcript.

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

- A kept mark and a paste are each one object: select, move, edit its words, ungroup, delete. He can group his own ink.
- Nothing Larry, Claude or a paste adds covers ink that was there first, unless Larry meant it to (a circle round a word).
- Larry can ask for room, and the board works out how much to open from what the reply needs and what is already blank.
- Igor can open and close room by hand.
- Moving ink is one undo, never scales a stroke, never splits a line of writing or an object.
- Every board that exists opens unchanged, and an older build still opens every board.

## Non-goals

- The board deciding which of Igor's strokes belong together (recognising his lines, paragraphs or diagrams). His ink
  is ink until he groups it. Reflow moves it
  by where it sits, never by what it means. A header (below) is a flag on a row of his ink, not an object.
- Reshaping: no resize handles, no rotating, no dragging an arrow's end. Move, reword, delete.
- Arrows that stay attached to what they point at when one end moves.
- Sideways reflow or columns. Room opens across the whole page width, downward only.
- The board reading his handwriting to find headings by itself. He marks a header, or Larry suggests one.
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
- **That is every kind of mark Larry or Claude can send**: a label, a box, a circle, an arrow, a line, an arc, a
  freehand curve. Each lands as its own object when kept, never as loose ink. A label is an object with words (Edit
  rewords it); a box, a circle and the rest are objects without words (select, move, delete). Igor, 2026-11-16:
  "Larry should be able to also send circles and boxes and text shapes that land…" (his note was cut off there; this
  is how it was read).
- **A paste** makes one object for the whole block of text, not one per line.
- **Copied strokes pasted with ⌘V** stay plain ink, as they were ink when copied.
- **Igor's own strokes are never objects by themselves.** He can make them one: with strokes selected by the lasso,
  **Group** makes the selection a single object without words, so it moves and deletes as one and no cut ever passes
  through it. This is how a diagram of his stays whole. (Where *Group* is offered depends on whether the lasso's own
  menu can take an item; if not, it sits in the press-and-hold menu while a selection is up. For the iPad to say.)
- A ghost is not an object. It is still nothing until kept.

### Select, move, edit, delete

What a finger does on paper is still unsettled in the main spec (a finger tap already keeps ghosts; a drag pans). So
the finger parts below are a proposal to try on the iPad, as *Igor's room, by hand* is.

- **A finger tap on an object selects it**: a thin outline round it and a small row of buttons beside it, placed like
  Keep and Dismiss are today (wholly on screen, following the object as the board moves). The Pencil never selects; it
  draws, through an object as through anything.
- **The buttons:** **Edit** (objects with words), **Ungroup**, **Delete**, and a grip to drag. *Ungroup* turns the
  object back into plain ink where it sits; nothing on the board changes but what a tap picks up. One undo regroups it. A tap elsewhere, or starting to draw,
  puts them away and changes nothing.
- **Move:** dragging the selected object by its grip moves it; a drag anywhere else still pans the board. It lands where it is dropped, even on ink: Igor put it
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

## Technical: object types

Igor, 2026-11-16: "Maybe there's a technical section. What are the object types? Do we have object types for text as
well as ink that we can sort of treat interactively?"

Yes: there are two families. **Ink things** hold only strokes. **Text things** hold words as real text and are drawn
on the board as ink. Both are picked up, moved and deleted the same way; only text things can be reworded. (This
section is about what exists and what each can do, not how it is coded.)

| Type | Holds | Stored as | Igor can | Larry sends / reads | Reflow |
|---|---|---|---|---|---|
| **Plain ink** | One stroke of his handwriting or drawing. | A stroke in the drawing. Nothing else. | Draw, erase, lasso. | Reads it, with when it was drawn. Never sends it. | Slides down or up with its row. Never split, never scaled. |
| **Ink group** | Strokes of his own that he grouped: a diagram, a formula. | The same strokes, plus a note listing them. | Select, move, delete, ungroup. | Reads it as a group with its box. Doesn't send one. | Moves whole. A cut never passes through it. |
| **Kept shape: box, circle, arrow, line, arc, curve** | One mark of Larry's or Claude's, kept. The strokes that draw it and the shape's own numbers (corners, centre, ends). | Strokes, plus a note with the kind, the numbers, the look, who made it and which reply. | Select, move, delete, ungroup. Not reshape. | Sends each as a mark. Reads back which were kept, and where they are now. | Moves whole. |
| **Kept label** | A kept mark with words: the words, and the strokes that draw them. | The words as real text in the note, with the look; strokes on the board drawn from them. | Select, move, **reword**, delete, ungroup. | Sends the words and where. Reads the words back as text. | Moves whole. Rewording redraws it and makes room if it grew. |
| **Pasted text** | A block of text from the clipboard: the words, the width it wraps at, the strokes that draw them. | The words as real text in the note, with wrap width and look; strokes drawn from them. | Select, move, **reword**, delete, ungroup. Lands selected. | Doesn't send one. Reads the words as text, not as a picture of letters. | Moves whole. Rewording re-wraps by word at its width and makes room if it grew. |
| **Header** | A flag on one row of his own ink, and whether its section is folded. | A note naming the row's strokes. The strokes are plain ink. | Mark, un-mark, fold with −, unfold with +. | Reads the sections and which are folded. Later, suggests one. | Its section moves as one block; folded, it is a solid block. |
| **Room** | Not a thing on the board: an act. Where a cut was, how far the ink moved, when. | A short history of pushes in the note. Room Larry has asked for and Igor hasn't opened is a ghost, stored nowhere. | Open by hand, close blank paper, undo. Tap *Make room* on Larry's. | Sends `insert-space`. Reads the pushes since his last look. | It *is* the reflow. |
| **Audio-anchored stroke (future)** | Any stroke, plus where in a recording it was drawn. | Not designed. Each stroke already records when it was drawn; the recording would be new, kept beside the board. | Play the board back; tap ink to hear what was said then. | Not designed. | Unaffected: the anchor is a time, not a place. |

A ghost is none of these: it is nothing until kept.

### Is a text object real text, or ink?

Both, on purpose. **The words are real text; the ink is how they are drawn.**

- The words are kept as text. Editing is typing. Re-wrapping is by word: change the words, or later the block's
  width, and the lines break again where words end and the block redraws.
- On the board it is strokes, the letters' outlines, as a paste is today. So it is in every picture, in the strokes
  Larry gets, in the saved board, on the phone and in an older build with no extra work, and the eraser, the lasso
  and zoom treat it like everything else on the page.

| | Words kept, drawn as ink (proposed) | A real text box on the board | Ink only (today) |
|---|---|---|---|
| Edit the words | Yes: type, and it redraws | Yes, with the system's cursor and selection | No |
| Re-wrap by word | Yes, on edit or a width change | Yes, live | No |
| In Larry's picture and strokes, the phone, older builds | Yes, as ink, unchanged | No: each needs to learn a second kind of thing, and older builds can't show it | Yes |
| Eraser and lasso | Work on it; a partial erase ungroups it | Don't touch it | Work on it |
| Looks like the rest of the board | Yes: ink | No: type among handwriting | Yes |
| Select a word, put a cursor mid-line on the board | No: editing is in a small field over the board | Yes | No |
| Long text | Capped (500 characters today): every letter is strokes | No real limit | Capped |

**Proposed: words kept, drawn as ink.** It gives the two things asked for, text that can be edited and that reflows
by word, without a second kind of content on the page. What it gives up is editing in place with a cursor, and long
documents; a board is not where those belong. If long typed notes ever matter, a real text box is the upgrade, and
the words are already stored as text to make it from.

### Could the board read his handwriting?

Probably, on the device, and it would be an addition beside the ink, never a replacement for it.

- **What exists.** Apple's Vision text recognition reads handwriting from a picture, on the device, and the board
  can already draw any region as a picture. PencilKit's own handwriting features (searching and copying handwriting
  as text in Notes) are, as far as this design knows, not offered to other apps; that wants checking before anything
  is promised. Larry already reads the handwriting from the strokes, so his reading is a second source that costs
  nothing new.
- **Searchable.** Recognised words kept as an index beside the board would let boards be found by what is written on
  them. This matters once there are more boards than fit in memory; "no search" is a non-goal of the whiteboard
  today, and this is what would lift it.
- **Convertible.** *Make text* on a group or a row would turn handwriting into a text object, which can then be
  reworded and re-wrapped. This matters most for headers (an outline with typed titles, a list of sections) and for
  handing a board's words to something else. It is lossy: his cursive is often misread, so it must be his tap, shown
  before it replaces anything, and one undo.
- **Not proposed now.** Nothing in grouping, room, reflow or folding needs the board to know what the ink says. It
  goes in *Features to build* as a later row if he wants it.

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

Igor, on this design's review page, 2026-11-16: "I should be able to request a room as well. Press and hold Insert +
Space. Or maybe insert a box, and it lets me draw a box, kind of like we can do on the Kindle [Scribe]." So asking for
room is his as much as Larry's, and it is in the first slice: it needs nothing from Larry or the Cockpit.

Two ways in. Both end the same way: room opens at a clear line, everything below slides down, one undo.

**A. Press and hold, then *Insert space* (proposed).** The same morning he asked that press-and-hold "bring up a menu
that does something useful" (bead `context-grabber-y4y`); this is its first useful item.

- A finger pressed and held on the paper brings up a small menu at that spot. *Insert space* is in it. (What else the
  menu holds is that bead's to say; *Paste* is the obvious second.)
- Choosing it shows a line across the page at the clear line nearest the press, with a grip under the finger.
- Dragging the grip **down** opens room as it goes, a line at a time, the ink below sliding with the finger. Dragging
  back **up** gives it back, and past where it started closes blank paper that was already there, stopping at the
  first ink. Lifting ends it.
- A tap on *Insert space* with no drag opens three lines, so it is useful with one hand.
- The Pencil's own press and hold is left alone: it draws.

**The left margin is a handle too** (Igor's pick, 2026-11-16: "use the left margin as my handle"). A finger pressed
and held in the page's left margin skips the menu: the line and its grip appear at the nearest clear line at once,
and the same drag opens or closes room. It is the quick way when he already knows he wants room; the menu is the way
that can be found without being told. Both are in the first slice and both are the same gesture after the first
touch.

**B. Draw a box, as on the Scribe.** *Insert space* arms a one-shot tool; he drags a rectangle with the Pencil or a
finger, and room as tall as the box opens at the box's top edge (moved to the nearest clear line). The box is not
kept as ink. The tool is offered from the same press-and-hold menu and from the Board menu.

| | A. Hold, pick, drag down | B. Draw a box |
|---|---|---|
| Says exactly what it does | Yes: a line and a height | Not quite: a box has a width, and room is always the full page width. A narrow box beside a diagram would still move the whole row. |
| Sees the result while sizing | Yes, the ink moves under the finger | Only on lifting |
| Close room again | The same drag, upward | Needs a separate way |
| Works with the Pencil in hand | Finger holds, finger drags; the Pencil never leaves ink mode | Needs a tool mode, so the next Pencil stroke isn't ink. A mode he forgets he is in eats a stroke. |
| Familiar | Like a text cursor's menu | Like the Scribe, which he already uses |
| Depends on | A finger hold being told from a pan (unsettled on paper) | The Board menu alone is enough |

**Proposed: A (with the margin handle, which is decided), and B's entry point as the fallback.** A does one thing the box can't (close room, and show the push
live) and never puts the Pencil in a mode. If the iPad shows a finger hold can't be told from a pan on paper, B from
the Board menu is what ships instead, since it needs no hold at all. Building both is the third choice: one more
thing in the bar for the same result.

- By hand there is no sum: the room is as tall as the drag or the box, in whole lines.
- The cut still snaps to a clear line, so his hand can't split a line of writing either.
- Blank bands below take up the push once that step is built (step 5); in the first slice the push is rigid.
- The whole gesture is one undo.

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

## Outlining with ink: headers and collapse

Igor, 2026-11-16: "In fact, I should probably be able to do collapsing as well. We could have headers and collapse
stuff, so I could use + and -. How could that work so that we have a combined outlining sort of setup with Ink?"

It works because of two things already above: the board can find **rows** (the ink between two clear lines), and it
can slide everything below a line up or down. A header is a row with a flag on it. Collapsing is closing the room
its section takes; expanding is opening it again.

### Marking a header

A header is one of his own rows of handwriting, flagged. It is not an object: it stays his ink, drawn and erased like
any other. Three ways to flag one:

- **A finger tap in the left margin beside a row** (proposed). A faint **−** appears there and the row is a header.
  The margin already belongs to the finger: a hold there opens room, a tap there marks a header. A tap on a
  header's own − folds it (below); to un-mark a header, press and hold its − or + and choose *Not a header*.
- **Press and hold on a row, then *Make header*** in the same menu as *Insert space*. The way that can be found.
- **Larry suggests one.** A later step: a mark that says *this row reads like a heading*, shown as a faint − in his
  colour, kept or dismissed like any ghost. He reads the words; the board never tries to.

Not proposed: the board guessing headers from underlines, size or a symbol he writes. It would be wrong often enough
that he would stop trusting the margin.

### What a section is

- A section is its header row and **everything below it down to the clear line above the next header**, or to the end
  of the ink. Ink belongs to a section by where it sits, so writing added under a header joins it with no step.
- Whatever is above the first header belongs to no section and never folds.
- **One level to begin with.** Every header is a sibling. Nesting is an open question below.
- Erase a header's ink and the flag goes with it: its section joins the one above. No ink is lost.

### + and −

- An open header shows **−** in the left margin; a folded one shows **+** and, after its row, a faint tag saying what
  is tucked away: *14 lines*. Neither is ink, like the page number.
- **A finger tap on − folds the section.** Its body disappears, and everything below slides up to sit one line under
  the header, exactly as closing room does. **A tap on + unfolds it**: the ink below slides down and the body is back
  where it was, stroke for stroke.
- *Fold all* and *Unfold all* sit in the Board menu: an outline of the whole board in one tap.
- Folding is not on the undo stack. Undo takes back ink, never a fold, so an undo can't spring a section open.
- A board opens folded as he left it on this device.

### Folding and the rest of this design

- **Nothing folded is ever removed from the board.** The saved board is always the whole board, unfolded. Folding is
  how this device shows it, remembered in the note beside the ink. An older build, the look-only phone and a lost
  note all show everything, unfolded.
- **A folded section is a solid block for reflow.** It moves with its header in a push. Room can't be opened inside
  it, and a cut never lands in it.
- **Ink can't land in a folded section.** A paste goes to clear paper that is showing. A ghost of Larry's that belongs
  inside a folded section shows on the header's + as a count (*2 marks inside*), and a tap unfolds the section so the
  marks can be seen and kept.
- **Writing directly under a folded header** is on the paper that is showing, so it lands after the folded body, in
  the same section, and is there when he unfolds.
- **Trade-off, named:** page numbers and page lines count the paper as it shows. Fold a long section and *Page 3 of 5*
  becomes *Page 2 of 3*, and writing that was on one page shows on another. The alternative, pages fixed to the
  unfolded board, leaves page-sized holes where folded sections were. The half-line drift on ruled paper applies to a
  fold as to a push.
- **Cost, named:** this is the first place the board shows something other than exactly what is saved. Every stroke
  drawn on a folded board has to be put back at its unfolded place before it is saved or sent. That is the same
  carrying that late replies need, running the other way, and it is why outlining comes after the push is proven.

### What Larry, the strokes and the export see

**Everything that leaves the board is the whole board, unfolded.** One rule:

- **The strokes** are every stroke, at its unfolded place, as today. With them goes a `sections` list: for each, its
  header's strokes, the span it covers, and whether it is folded. Larry's reply lands by the same frame as today
  whatever is folded.
- **Larry's picture** of the pages on screen shows their sections unfolded. A folded section in it is drawn in full,
  and the `sections` list tells him it was folded, which is a real signal: it is what Igor has set aside. Larry is
  asked to answer what is open unless a question points into a fold.
- **The list's picture, a shared picture and iCloud** carry the whole board. A folded section is never missing from
  anything he exports.

Trade-off: Larry and Chat see more than Igor's screen does. The other way, sending the board as folded, gives Larry
a shorter picture focused on what is open, at the price of marks that must be carried back through every fold and a
Chat picture that silently lacks ink. Proposed: whole board, with folds flagged.

### Slice

Its own slice, after the first slice (the push) and after objects (which brings the note the flags live in): headers
by margin tap and menu, fold and unfold, `sections` with the strokes. Larry suggesting headers, and nesting if wanted,
follow.

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
| Newer app | Older Cockpit | The Cockpit drops fields it doesn't know from messages and strokes, so `can` never reaches Larry and he answers as today. Pushed strokes read as erased and new, which is wrong but harmless. A Cockpit that doesn't know `insert-space` refuses the whole reply that carries one, as it refuses any mark it can't check, so nothing half-lands; `can` not reaching Larry is what keeps him from sending one. Both are why the Cockpit goes first. |
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
- Objects: grouping a selection makes one object and ungrouping leaves the same strokes as plain ink, each one undo;
  all strokes moved together stay one object; any stroke lost or parted dissolves it; undo restores it; an
  unreadable or stale note gives a board of plain ink and no error.
- Room by hand: as tall as the drag in whole lines; dragging up closes only blank paper and stops at ink.
- Sections: a section runs from its header to the clear line above the next; folding slides what is below up to one
  line under the header and unfolding puts every stroke back exactly; a stroke drawn on a folded board is saved at its
  unfolded place; a push carries a folded section whole; erasing a header's ink removes the flag and no ink.
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
taken back by its undo; *Insert space* by hand opens the room dragged and one undo closes it; the session log says each cut, sum and push in numbers.

**iPad only**: whether a finger tap selects an object cleanly and a drag on its grip moves it without panning the
board; whether a finger press and hold, on the paper and in the margin, can be told from a pan, and a margin tap from
both; how a fold looks as it closes; and whether
the ink keeps up with the finger while room is dragged open; how a large push looks (a jump or a
slide) and whether the paper under the Pencil redraws at once; the lasso and both erasers on an object; that kept ink
shows after a push (the "saved and counted but not shown" bug has happened before on paper); a real late reply from
Larry while Igor keeps writing.

## Acceptance

For the first slice (below). Each later slice adds its own when it is specified for building.

- Fill a screen with writing, copy two lines of text and tap Paste: the text lands on blank paper, covering no stroke.
  If the screen had a clear patch big enough, nothing else moved.
- The same with no clear patch: the writing below the nearest clear line has slid down by whole lines, every stroke
  the same size and shape as before, and the text sits in the room. No line of writing was cut in two.
- Undo once: the text is gone, the writing is back where it was, and any page the push added is gone with it. Redo
  brings all of it back.
- Send Larry the board, write two more lines under what he saw, and Keep his mark when it lands on them: those two
  lines move down and the kept mark sits clear of them. One undo takes back both the keep and the move.
- Keep a mark of his that circles a word that was in his picture: nothing moves.
- A push that carries writing past the last page: the board has the pages it needs and a blank one below.
- A ghost showing below the cut when a push happens is still beside the same ink afterwards.
- Send the board to Larry after a push: the Cockpit's count of new strokes is only what was added, not everything
  that moved.
- Press and hold between two lines of writing, choose *Insert space* and drag down three lines: the writing below is
  three lines lower, the writing above hasn't moved, and one undo puts it back. Drag back up past the start: blank
  paper closes and stops at the first ink.
- Press and hold in the middle of a word and choose *Insert space*: the line appears between lines of writing, not
  through the word.
- Press and hold in the left margin and drag down: the same room opens, with no menu.
- A look-only board: no paste, no *Insert space*, no margin handle, no push, nothing moves.
- The session log says, for each push: where the cut was asked and where it landed, what was needed, what was already
  blank, how far the ink moved and how many strokes moved.

## Decisions (Igor, 2026-11-16)

Picked on this design's review page. Where the text above says *proposed* for one of these, it is now decided.

1. **"The space existing @ margin time" meant both readings.** Blank paper already there when room opens is spent
   before any ink moves, and the left margin is his handle for opening room by hand.
2. **Larry's room waits for his tap** on *Make room*. It never opens on its own.
3. **A paste on a full screen makes room and lands selected**, with Delete beside it. It is not a ghost to keep.
4. **Erasing part of an object dissolves it**: what is left becomes plain ink.
5. **His own writing does not push Larry's objects**, not in the first build. He opens room by hand.

Also his, the same day: he can ask for room himself (*Igor's room, by hand*), and Larry's circles, boxes and text land
as objects (*How things become objects*; that note arrived cut off, so the reading wants his nod).

## Open questions for Igor

1. **How do you ask for room, besides the margin handle: hold and drag (A), draw a box like the Scribe (B), or both?**
   Proposed: A, with B as the fallback if a finger hold can't be told from a pan on the iPad. See *Igor's room, by
   hand*.
2. **What marks a header?** Proposed: a finger tap in the left margin beside the row, with *Make header* in the
   press-and-hold menu as the way that can be found, and Larry suggesting headers later. The other choices are the
   menu alone, or a symbol you write that the board recognises (not proposed: it will guess wrong).
3. **One level of headers, or nested?** Proposed: one level first. Nesting would go by indentation (a header that
   starts further right folds inside the one above), which asks the board to judge how far right is "indented" in
   handwriting.
4. **What does Larry get of a folded section?** Proposed: all of it, flagged as folded. The other choices are only
   its header, or the board exactly as it shows on your screen.
5. **Which "Outlining" did you mean?** Classic OneNote's + and − outlining, the iPad app named Outline, or something
   else. It decides what the folding should feel like.
6. **What is "replay"?** The ink redrawing itself in time with the recording, or a transcript of what was said written
   back out. They are different features; row 20 covers whichever you meant.

## Smallest first slice

Fixes the stated pain (things landing on ink) and lets Igor ask for room himself. It needs no object note, no new mark
and nothing from Larry or the Cockpit beyond item 5:

1. **The sum and the push**, as host-tested arithmetic: clear lines, needed against already there, whole-line push,
   one undo. No taking-up by blank bands below yet: a rigid push.
2. **Paste lands in clear paper or makes room.** Still plain ink, not yet selected.
3. **Keep makes room when Larry's ghost covers ink newer than his picture.**
4. **Room by hand**: the left-margin handle, and press and hold, *Insert space*, drag down to size it (or the box
   tool from the Board menu, if the iPad says the hold can't work).
5. **`was` on moved strokes, and the Cockpit honouring it**, so the first push doesn't tell Larry the whole page is new.

Then, each its own slice: objects (the note, select, Delete, move, Edit); Larry's `insert-space` with `can`; blank
bands taking up the push; outlining (headers and collapse).
