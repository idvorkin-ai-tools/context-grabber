# Whiteboard: headers drawn in ink

Issue [#967](https://github.com/idvorkin/context-grabber/issues/967). Igor, on board 302d5345 (2026-11-19, relayed by
Larry): "A line drawn under handwritten text, or a leading #, makes that line a header, plus a way to end a header
section."

This builds on *Headers fold their sections* in [Larry edits the board](2026-11-16-whiteboard-board-ops-design.md):
a header is the same header a margin tap makes, with the same ▾, folds, sections, levels and erase. Nothing here is
a second kind of header; only the ways one is made and the ways a section ends are new.

## Goals

- Igor makes a header the way he would in a notebook or in Markdown, with the Pencil, without reaching for the margin.
- A section can end where Igor says it ends, not only where his indent comes back.
- A wrong guess costs one Undo, and never comes back on its own.
- Larry sees which lines the board takes for headers.

## Non-goals (this slice)

- Old ink is never converted. A board opened with underlined lines on it keeps them as they were (the faint H still
  offers them); only an underline or a # drawn from now on makes a header.
- Header levels by mark (`#` against `##`) were left out of the first slice; they came next ([#1034](https://github.com/idvorkin/context-grabber/issues/1034),
  *Header levels: ## and ###* below).
- Larry making or unmaking headers, and any change to what the Cockpit is sent. (Larry needs no wire or op change.)

## What Igor sees

### An underline makes the line above it a header

- **When Igor draws a straight, flat line under a line of his writing**, across most of its width, that line becomes
  a header as soon as he lifts the Pencil: the ▾ shows in the margin beside it, as after a margin tap.
- The underline is the same one the faint H already looks for: long (60 points or more), flat and straight, its
  middle just under the writing (from a third of the way up the letters to a little over half a line below them),
  and covering at least seven tenths of the line's width.
- An underline that runs far past the writing (more than half as wide again as the line, plus a line's height) is
  not an underline: it is a rule (below).
- The underline belongs to the header: it folds with it, moves with it and is erased with it.
- Only Igor's own writing is made a header this way, never one of Larry's groups or kept texts, and never a line that
  is already a header.
- A group Igor made of his own ink (the web board lets him group) is still his writing: it can be underlined, take a
  #, join a header's row and make a line of writing, and it still moves whole. Only Larry's groups and kept texts are
  not his writing (Igor, 2026-11-24, bead context-grabber-xzmc). On the iPad every group is Larry's, since only Larry
  groups there.

### A # at the start of a line makes it a header

- **When Igor writes a # at the start of a line**, the line becomes a header as soon as the # is finished, before or
  after he writes the words after it.
- A # is four short straight strokes, two of them roughly level and two roughly upright (or slanted up to about 35°),
  each level one crossing both upright ones, all inside a box no bigger than about a line and a half each way. It is
  the leftmost ink on its line.
- The # stays on the board as ink: it is part of the header's row.

### Writing more on a header's line

- Anything Igor writes on a header's own line afterwards is part of the header's row: the header's words written
  after the #, or a word added to an underlined header. It folds with it, the fold's "▸ N lines folded" sits past it,
  and the margin's ▾ stays one mark. This holds for every header, a margin tap's included.

### Seeing the headers (#1004)

Igor, on the iPad (2026-11-20): the ▾ was a small grey mark at a different place beside each header, hard to see and
hard to hit, and the ▾ of a line he started with a # in the margin didn't show at all, so he took the line for
unrecognised. (It was a header: the ▾ sat in the margin's middle, under the very # that made it.)

- **The moment a line becomes a header** (an underline, a #, a margin tap or *Make header*), its row is tinted in the
  accent colour for about a second, then the tint fades. Words written on a header's line afterwards don't tint it
  again, nor does opening a board, an Undo or a Redo.
- **Every header's ▾ sits in one spot**: at the margin's left edge, the same place for every header whatever its
  indent, standing on the line's baseline as a letter of the line would (not its middle, which a g's tail or an
  underline pulls down). A folded header's ▸ and its lines sit in the same spot.
- **The ▾ is over the ink**, on a small plate of the paper's colour with a thin edge, so ink written in the margin
  (a # started there) never hides it. It covers only the margin's left corner of that line.
- **The ▾ is easy to hit**: a tap in the margin anywhere within 22 points above or below the ▾'s middle (44 points
  top to bottom, the margin's full width across) is on its header, as is a tap beside the line's ink, as before.
- The faint H beside a line that looks like a header is unchanged: under the ink, in the margin's middle.

### Header levels: ## and ### (#1034)

Igor, 2026-11-20 (decision O2): "Keep [the #967 ink header design]; build ## and ### levels next."

- **A line started with `##` is a level-2 header, with `###` a level-3 one.** A single # or an underline still makes a
  level-1 header, and so does a margin tap or *Make header*.
- **Igor writes the #s one after another.** The first # makes the line a level-1 header as before (its row tints).
  Each further # finished right beside the header's #s (no more than about three quarters of a line away, with none
  of the header's words between) takes the header one level deeper, at once: ## is level 2, ### level 3. The row
  tints again for each new level, as it did when it became a header. A fourth # is
  plain ink on the header's line. Only a # header deepens: a # drawn after an underlined or margin-tapped header's
  words is its row's ink, as any writing on its line is.
- **The level shows in the margin**: an open level-2 header's mark is ▾ ##, a level-3 one's ▾ ###, in the same spot
  as every header's ▾; a level-1 header's is the ▾ alone. A folded header's mark is ▸ and its lines, with the #s after
  them on a deeper header (▸ 4 ##).
- **A level-N section runs to the next header of level N or shallower**, or to a rule: so a ## under a # is inside
  the #'s section, and the next ## or # ends the ##'s section. Folding a level-1 header folds its ## and ### sections
  with it, as a section folds the headers inside it today; unfolding it brings them back as they were, a folded ##
  still folded.
- **Indents still count for headers of one level**, as before: a margin-tapped header indented under another nests in
  it, and a line coming back to a header's indent ends its section when its first line was indented. But once a
  deeper header (a ## under a #) has started inside a section, only a header of its level or shallower, or a rule,
  ends it: the ##'s own unindented lines don't end the # above it. A shallower header (a # after a ##) ends the
  ##'s section wherever its indent.
- **The outline's levels** (*Fold all*, *1*, *2*, *3*) still go by how deep each header nests, which now follows the
  #s: a ## under a # is level 2. A ## with no # above it is the outline's level 1.
- **Undo of the last # takes one level**: the header goes back to the level it had (Redo brings the level back).
  Undo or erase of the first # still takes the whole header, as before.
- **Erasing a bar of a further # takes the header back to the level before that #**, so a ### whose middle # loses
  a bar is a level-1 header (the #s after it no longer count). **Redrawing the bar brings every # still on the board
  back**: the ### is ▾ ### again, not ▾ ##, and the third #'s strokes are its #s again, not the row's ink.
- **Larry's picture labels a deeper header with its level**: "▾ ## header", "▾ ### header". A level-1 header's label
  stays "▾ header". A folded header's "▸ N lines folded" is unchanged; its #s are in the picture's ink.
- **The session log** says when a # took a header a level deeper, and to which level.
- **Not in this slice:** a double underline as level 2 (two flat lines under a line read as an underline and a rule
  or a strike as often as a level, so it isn't cheap to tell apart), and levels below ###.

### A rule across the page ends the sections above it

- **A long, straight, flat line that underlines nothing** (at least about half the page wide, and not just under a
  line of writing it would underline) is a rule. A section ends at the first rule below its header, as it ends where the ink
  comes back to the header's indent, at the next header, or where ink written under the header while it was folded
  begins (the board ops spec, *Headers fold their sections*): whichever comes first.
- The rule and what is below it never fold into the section above. Folding a header slides the rule up, with the rest
  of what is below, to a line or two under the header.
- A rule ends every section open above it, outer ones included, as a horizontal rule ends them in Markdown.
- A rule is plain ink in every other way: Igor erases it to let the section run on. It never puts a faint H beside
  the line above it: the faint H looks for the same underline the ink does, one that doesn't run far past the writing.
- A rule is read wherever it is, ink drawn before this build included: it is never kept, only seen. A shorter flat
  line (a dash, a strike) is plain ink and ends nothing.

### Undoing a wrong guess

- **One Undo takes the mark and the header with it.** The underline or the #'s last stroke was the last thing drawn;
  Undo takes that stroke away and the line is no longer a header (its ▾ goes). Redo brings the stroke and the header back.
- **Erasing the mark** (the underline, or any stroke of the #) also makes the line plain again, the header's words
  left as they were. A folded header keeps its fold until it is unfolded: erasing its underline never springs or loses
  a fold, nor takes the folded section with it. The eraser across a folded header's underline or # takes only that
  stroke; only its words or its "▸ N lines folded" take the section (the board ops spec, *Headers fold their sections*).
- ***Not a header*** in the hold menu keeps the underline or # as ink and makes the line plain. While the choice
  is in effect, the board keeps the line plain and shows no faint H, even after more words are written on the
  line or the board reopens. A new underline or #, a margin tap, or *Make header* can make the line a header again.
  See [the outline's Undo rules](2026-11-16-whiteboard-board-ops-design.md#headers-fold-their-sections).
- A wrong rule is erased or undone like any stroke, and the section runs on as before.

### Larry sees the headers

What a turn sends Larry is a picture of the board, its strokes (in board points, each with its id) and the board's
events. The strokes carry no headers: the underline or # is a stroke like any other, and only a *folded* section goes
beside the strokes, under its header. So the picture is where Larry learns which lines are open headers (#1001: a ▾
in the margin's middle sat on the very # it marked, or fell outside the picture when the line started further in, and
Larry saw plain strokes).

- Every picture of the board (Larry's turn, Send, Claude's turn) labels each open header in words, in grey 14-point
  letters: "▾ header", starting 14 points past the end of the header's line, where the board puts a fold's marker. The
  label never sits on ink, and reads as what it is without the board's margin to explain it. Larry reads the ink's
  underline or # and the label together: this line is a header and can fold.
- A folded header's section is drawn whole and shaded, with a grey ▸ beside the header and "folded" at the section's
  top (#1013). An open header in such a picture is labelled as above.
- The picture always takes in these labels: it grows past the ink to hold them rather than cutting them off.
- The board itself is unchanged: its margin shows the ▾ (see *Seeing the headers*).
- What Larry is sent besides the picture is unchanged: the strokes stay plain ink, and folded sections go under their
  header as before. If Larry is asked, he finds the headers in the picture, not the strokes.

### The session log

- Every header the ink makes is in the session log: by an underline or a #, the line's place, and the strokes it took,
  so a phone's log says why a line became a header. A header made plain again by its mark's Undo or erase is logged
  too.

## Acceptance criteria

- Drawing an underline under a line of writing shows ▾ beside it at once; a tap on the ▾ folds the section below it.
- Writing # and then words at the start of a line shows ▾ beside it; the fold marker lands past the words, not over
  them.
- A rule drawn across the page under a section's lines ends the section there: folding the header hides only the
  lines above the rule, the last one included even when the rule touches it, and the rule slides up under the header.
- One Undo after an underline or a # that made a header takes its last stroke and the ▾; Redo brings both back.
- *Not a header* on an underlined header leaves the underline and no ▾, and drawing elsewhere never brings it back.
- After *Not a header* the line shows no faint H either, nor after the board is closed and opened again; a margin
  tap beside it still makes it a header.
- A board opened with underlines drawn before this build shows them as they were: faint H, no header.
- Larry's picture labels an open header "▾ header" just past the end of its line, clear of the ink and inside the
  picture however far in the line starts.
- Making a header (by an underline, a #, a margin tap or *Make header*) tints its row for about a second; writing more
  on its line doesn't.
- Two headers at different indents have their ▾ at the same place across, each standing on its line's baseline.
- A # written in the margin's left corner leaves its header's ▾ showing over it.
- A tap in the margin anywhere on the ▾, or up to 22 points above or below its middle, folds its header.
- Writing ## at a line's start shows ▾ ## in its margin; a third # makes it ▾ ###; one Undo takes it back to ▾ ##.
- Under a # header, a ## header's section ends at the next ## or #, and folding the # hides the ## and its lines
  with the rest of the section.
- Larry's picture labels an open ## header "▾ ## header".

## Future work (not in this slice)

- A double underline as a level-2 header, and levels below ###.
- A double rule, or a rule with a word on it, as an end of everything, or a page break.
- Larry told about open headers in the strokes, not only in the picture (it needs a Cockpit change; #1001).
- Larry making a line a header (an op), and *To text* turning a header line into a kept text that is still a header.
- A header made by a live-snapped line: a snap swaps the stroke, so the header's mark is lost and the line goes plain.
  The snap should hand the header to the clean line.
- Recognising a header from handwriting recognition (the words "#" or "1." read by the model) rather than geometry.
