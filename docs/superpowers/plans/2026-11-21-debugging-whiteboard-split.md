# Plan: split the whiteboard rows out of DEBUGGING.md (bead context-grabber-n9rj)

A move, no behaviour change. The whiteboard's rows of the session-log table in `docs/DEBUGGING.md` were single table
lines up to 14,600 characters long, so every change that logged a new board event edited the same line and conflicted
with every other.

1. Move the thirteen whiteboard rows (Whiteboard, Pen paths, Question cards, A board on paper, Ghosts on paper, Lines
   and colour on paper, Paste on paper, Larry's wait on a board, Larry's board ops, Connectors, To text and shape snap,
   The board's ? and Feedback, Rewording a kept text) into `docs/debugging/whiteboard.md`: one `##` section per row,
   its area cell as the heading, and its events cell broken into bullets, one event family or action per line, with
   nested bullets for the actions of a family.
2. The text is the rows' own: only the separators between events (` / `, `; `, `. `) became line breaks, a family's
   opening words gained a colon, and one "and" before the last action of a list was dropped. Checked by comparing
   each row with its section, whitespace and punctuation ignored.
3. Leave one pointer row in the table naming every event type that moved, and say in *Adding a line* that a whiteboard
   event goes in the new file on its own line.
4. Point the two other references (`docs/TESTING.md`'s touch-fixture section and a test comment) at the new file. No
   script or test parses `DEBUGGING.md`.
