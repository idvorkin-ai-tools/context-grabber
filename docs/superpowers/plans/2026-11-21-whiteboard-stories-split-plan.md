# Plan: split the whiteboard's stories by feature area

Bead context-grabber-9yxo. The whiteboard journey's one story file had grown past 8,400 lines and 423 stories, and
parallel PRs collided in it. It becomes nine files in `docs/stories/`, each holding one feature area's stories in
their original order, with every story's text unchanged:

| File | Feature area |
|---|---|
| `10-whiteboard-boards.md` | the board and the list: drawing, rename, delete, the bar, colour, the grid, paste, undo, the cheat sheet |
| `10-whiteboard-paper.md` | boards on paper: the trial, pages and lines, ghosts and paste on paper |
| `10-whiteboard-turn.md` | Larry's turn: asking, the picture and strokes, who answers, the wait, the note and the conversation |
| `10-whiteboard-marks.md` | ghosts and Larry's marks: Keep and Dismiss, their look, keeping groups, Tidy, room for a reply |
| `10-whiteboard-edits.md` | Larry changes the board: ops by name, what he hears, refused changes |
| `10-whiteboard-cards.md` | question cards |
| `10-whiteboard-gestures.md` | holds, scratch-out, snapped shapes, To text, connectors, reword, drag and the room handle |
| `10-whiteboard-outline.md` | headers, folds and levels |
| `10-whiteboard-storage-and-log.md` | unreadable and unsynced boards, unknown ink, the tool and touch log |

`10-whiteboard.md` is deleted rather than kept as an index, so a branch that still edits it gets a loud
modify/delete conflict: re-apply its stories in the file of their area.

The story-ID checker (`scripts/native/story-ids.py`) reads every file linked in a row's first column as that
journey's, keys the IDs column by journey (named by its first file), and fails on a file linked twice; its host test
gains the several-file cases (story 796). The links into the old file (two specs, the board-ops plan) point at the new
files. Move only: no app code, no behaviour change.
