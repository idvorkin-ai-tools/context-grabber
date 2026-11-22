# The whiteboard: Storage, sync and the log

Boards that can't be read or haven't synced, unknown ink, and what the board's log keeps about tools and touches. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 1060:

- **Summary:** A board whose drawing can't be read or moved aside is left as it was, and nothing saves over it
- **Status:** implemented in [2a9b1f0e](https://github.com/idvorkin/context-grabber/commit/2a9b1f0e); verified by host tests (`BoardKeepingTests`: bad bytes and a failed move leave the original and an older set-aside copy untouched through an edit's save, a relaunch and a reopen; a later open that can move it sets it aside beside the older one and the board saves again; a healthy board and a new one are never held), the Mac build, and the iPad simulator (rung 2, 2026-11-21: the 14 other whiteboard classes green on this change; `WhiteboardOnPaperUITests.testAnUnreadableBoardThatCannotBeMovedAsideOpensLookOnly`'s first open showed the copyable problem and *look only*, the session log `editable: false`, `kept_at: null` and the move's permission error; its rerun after taking out a drag a look-only board reads as swipe back waits on the Mac's screen unlocking). Not yet seen on the iPad
- **Issues:** [#1042](https://github.com/idvorkin/context-grabber/issues/1042) (bead context-grabber-75cg): a source review, 2026-11-21, "a subsequent save can overwrite the recoverable original"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The board is kept*

#### Use Case:
- **As someone** whose board file has gone bad on a device that won't let it be moved
- **I want to** see a problem I can copy, and have the board open look-only
- **so that** nothing I draw that time saves over a drawing that might still be recovered

#### Acceptance Criteria:
- **Scenario:** An unreadable board that can't be moved aside
- **Given:** a board of mine on paper whose saved drawing can't be read, and whose file can't be moved aside
- **When:** I open it, leave, and open it again
- **Then:** each time a copyable problem names the board and says it was left as it was, the board says *Couldn't be read: look only* and takes no ink, and the file and any copy set aside before are exactly as they were

---

### User Story 1061:

- **Summary:** A board whose newer version fails to come down from iCloud keeps showing the last one that did
- **Status:** implemented in [b00acbce](https://github.com/idvorkin/context-grabber/commit/b00acbce); verified by host tests (`BoardKeepingTests`: a failed copy, an unreadable or missing drawing and an interrupted asset each leave the old drawing and picture untouched and nothing removed first; a retry brings the new version; a failed first download leaves no file; a missing or failed picture still takes the drawing and says so) and the Mac build; still in the list while its newer version fails in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05) (`BoardIndexTests`). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a source review, 2026-11-21, "a copy failure can leave a reading device without its last viewable replica"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** keep seeing the last version that arrived when a newer one fails to come down
- **so that** a bad sync never leaves me with a blank board until the next good one

#### Acceptance Criteria:
- **Scenario:** A refresh that fails over a board already here
- **Given:** the iPhone has a board from the iPad, and the iPad has drawn more on it
- **When:** the iPhone's sync of the newer version fails partway, and I open the board offline, then sync again with the network back
- **Then:** offline it shows the version it had, the list says boards aren't syncing, and the next sync brings the newer version, with its picture drawn on the iPhone if iCloud's came without one

---

### User Story 1062:

- **Summary:** A broken copy of another device's board is repaired by the next good sync
- **Status:** implemented in [584037a4](https://github.com/idvorkin/context-grabber/commit/584037a4); verified by host tests (`BoardKeepingTests`: a held copy of another device's board is replaced by the next good copy and let go; a held board of this device's isn't replaced and still refuses saves). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a held replica made every sync fail, so the list said boards weren't syncing until that board was opened
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** have a copy that went bad on the iPhone replaced by iCloud's good one
- **so that** one broken copy never leaves the board unreadable or the whole sync failing

#### Acceptance Criteria:
- **Scenario:** A broken copy of another device's board is repaired
- **Given:** the iPhone's copy of the iPad's board can't be read and couldn't be moved aside
- **When:** the iPhone syncs and iCloud has a good copy of that board
- **Then:** the good copy replaces the broken one, the board opens to look at again, and the list doesn't say boards aren't syncing

---

### User Story 1063:

- **Summary:** A stroke of an ink the app doesn't know never closes the board
- **Status:** implemented in 61540121; verified by host tests (WhiteboardInkTests) and the Mac build; on the iPad and the iPhone since 2026-11-21 (311c4711); which ink it was is still owed, from the iPad's log
- **Issues:** [#1083](https://github.com/idvorkin/context-grabber/issues/1083), with [#1080](https://github.com/idvorkin/context-grabber/issues/1080), [#1081](https://github.com/idvorkin/context-grabber/issues/1081), [#1082](https://github.com/idvorkin/context-grabber/issues/1082), [#1084](https://github.com/idvorkin/context-grabber/issues/1084), [#1085](https://github.com/idvorkin/context-grabber/issues/1085), [#1092](https://github.com/idvorkin/context-grabber/issues/1092)–[#1095](https://github.com/idvorkin/context-grabber/issues/1095): the iPad closed three times in two minutes on 2026-11-21, each just after a stroke landed, when the board asked that stroke's ink for its kind
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Ink the app doesn't know never crashes the board*

#### Use Case:
- **As someone** writing on the iPad's board
- **I want to** keep writing whatever ink a stroke turns out to carry
- **so that** the board never closes under my Pencil and loses the thought I was on

#### Acceptance Criteria:
- **Scenario:** A stroke of an unknown ink lands on the board
- **Given:** a board open on the iPad
- **When:** a stroke arrives whose ink is of a kind the app has no name for
- **Then:** the board stays open, the stroke draws and saves, Larry gets it with its kind as the ink spells it, and the session log names that kind once

---

### User Story 1064:

- **Summary:** The log says which tool Igor picked, beside the one the board thinks it holds
- **Status:** implemented in 57255cf5; verified by `just native-test` (lint, host tests, script checks) and the Mac build; the iPad's log with both tools on a touch is still owed
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078): "Switched to eraser still drew normally"; every touch the iPad has logged names a black pen, including 11 that erased ink and the strokes Igor drew in blue
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says which tool Igor picked*

#### Use Case:
- **As someone** who reports that a tool did the wrong thing
- **I want to** have the log say which tool I had picked and which one the board used
- **so that** the fix goes after the real cause, not a guess

#### Acceptance Criteria:
- **Scenario:** Igor picks the eraser and writes
- **Given:** a board open on the iPad with the pen in hand
- **When:** Igor picks the eraser in the tool picker and touches the board with the Pencil
- **Then:** the log has a line for the change naming the eraser the picker shows and the tool the board holds, and the touch's line names both

---

### User Story 1091:

- **Summary:** The board acts on the tool Igor picked, not the one it thinks it holds
- **Status:** implemented in [2b6d48ab](https://github.com/idvorkin/context-grabber/commit/2b6d48ab); verified by `just native-test` (lint, host tests, script checks) and the Mac build. No host or UI test can see the picker disagree with the board, so the fold, card, snap and hold choices wait for the iPad's log
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078); bead context-grabber-ckv5 (whiteboard arch 1): 7,313 iPad touches logged the board's tool as a black pen, including 11 that erased and strokes drawn blue, so every choice made from it (folds, cards, label width, snaps, holds, headers) followed a pen Igor wasn't holding
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The board acts on the tool Igor picked*

#### Use Case:
- **As someone** switching between the pen and the eraser on the iPad's board
- **I want to** have the board treat each touch as the tool I picked for it
- **so that** the eraser takes a fold or an answered card, and a pen's stroke snaps or holds, whatever the board's own idea of the tool

#### Acceptance Criteria:
- **Scenario:** Igor erases across a folded header after picking the eraser
- **Given:** a board on the iPad with a folded header, and the tool picker showing the eraser while the board still reports a black pen
- **When:** Igor draws the eraser across the fold's marker with the Pencil
- **Then:** the fold goes as one *Erase*, and the touch's log line names the eraser as the picker's tool beside the board's own

---

### User Story 1098:

- **Summary:** A board opens drawing with the tool the picker shows, so a kept eraser erases from the first stroke
- **Status:** implemented in [3fe2f43d](https://github.com/idvorkin/context-grabber/commit/3fe2f43d); verified by `just native-test`, the Mac build, and the iPad simulator (`WhiteboardEraserUITests`: the eraser kept from the last launch drew a black line before the fix, and draws no ink after it; the eraser picked after the report sheet draws no ink); the iPad's Pencil is still owed
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078): "Switched to eraser still drew normally"; bead context-grabber-8o93. The picker opened on the eraser kept from before, and the board drew with its own black pen until the next pick
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board opens drawing with the tool the picker shows*

#### Use Case:
- **As someone** who left the eraser picked when the app last closed
- **I want to** have the board erase when the picker shows the eraser, from the first stroke
- **so that** what the picker shows is what the Pencil does, without picking it again

#### Acceptance Criteria:
- **Scenario:** The eraser kept from the last launch
- **Given:** the eraser picked in the tool picker, and the app closed and opened again
- **When:** Igor opens a board, sees the eraser selected, and draws across bare paper
- **Then:** no ink lands, and a pen picked after that draws as before

- **Scenario:** The eraser picked after the report sheet
- **Given:** a board open, and BugKit's report sheet opened and closed over it
- **When:** Igor picks the eraser and draws across bare paper
- **Then:** no ink lands

---

### User Story 1104:

- **Summary:** The log keeps each pen touch's path, and the stroke each gesture's verdict judged
- **Status:** implemented in [d644b7c8](https://github.com/idvorkin/context-grabber/commit/d644b7c8); verified by `just native-test` (host tests: the path's encoding, and Igor's real scratch-outs judged the same after it), the Mac build, and the iPad simulator (`WhiteboardScratchOutUITests` wrote `board_touch` paths and scratch lines with their zigzag, which `just touch-fixture` read back); the iPad's own Pencil paths are still owed
- **Issues:** bead context-grabber-y544 (whiteboard architecture review 2026-11-21, item 4): the log held only tallies, so a gesture bug on the iPad could not be replayed; bead context-grabber-x1zk waits on it
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A pen touch's path is in the log, and a pulled log replays on the Mac*

#### Use Case:
- **As someone** whose scratch-out, snap or margin hold did the wrong thing on the iPad
- **I want to** have the log keep the stroke I drew, not only how it was judged
- **so that** the fix is checked against my real stroke instead of a guess

#### Acceptance Criteria:
- **Scenario:** Igor draws with the Pencil
- **Given:** a board open on the iPad
- **When:** the Pencil lifts
- **Then:** the session log has a line with the touch's points in board points, their times, whether it ended or was called off, and the tool the picker showed
- **And:** a zigzag's scratch-out line, a margin hold's line and a snap's line each carry the stroke they judged
- **And:** the touch's own line does not go to the Cockpit with the board's log

---

### User Story 1105:

- **Summary:** A pulled iPad log becomes a host fixture of its gesture touches
- **Status:** implemented in [d644b7c8](https://github.com/idvorkin/context-grabber/commit/d644b7c8); verified by `just native-test` (host tests: a log's lines become cases, and every fixture's cases keep their verdicts) and the Mac build; `just touch-fixture` turned the iPad simulator's log into `Fixtures/touches/sim-scratch-out-2026-11-21.json`, the iPad and the Mac agreeing on all 3 scratch-outs
- **Issues:** bead context-grabber-y544
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A pen touch's path is in the log, and a pulled log replays on the Mac*

#### Use Case:
- **As someone** fixing a gesture bug Igor hit on the iPad
- **I want to** turn his pulled log into a fixture the host tests run
- **so that** the bug is settled in seconds on the Mac, and stays settled

#### Acceptance Criteria:
- **Scenario:** an agent replays a pulled log
- **Given:** a session log pulled from the iPad with pen paths in it
- **When:** the agent runs the fixture recipe on it
- **Then:** it writes a fixture of the log's scratch-outs, held lifts and margin tries, each with what the iPad decided and what the Mac decides, and names any case where they differ
- **And:** writing that is none of these stays out of the fixture unless every touch is asked for
- **And:** the host tests hold each case in the fixture to its expected verdict

---

### User Story 1090:

- **Summary:** A board whose first download from iCloud failed stays out of the list until its drawing arrives
- **Status:** implemented in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05); verified by host tests (`BoardIndexTests`: another device's board, and this device's own board back after a reinstall, are listed only once their drawing is here) and the Mac build. The simulator has no iCloud account, so the CloudKit path waits for the iPhone and the iPad
- **Issues:** bead context-grabber-1jb4 (codex review 2026-11-21, finding 4): the list showed a board from iCloud before its drawing came down, so a failed first download opened it blank; on the iPad that drew it, back after a reinstall, the blank board took ink and would have gone up over iCloud's copy
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** opening the iPad's board on the iPhone, or my own boards on a reinstalled iPad
- **I want to** see a board in the list only once its drawing is on this device
- **so that** I never open a blank board by mistake, or draw over one and lose what iCloud holds

#### Acceptance Criteria:
- **Scenario:** The first download fails
- **Given:** iCloud lists a board this device has never had the drawing of
- **When:** the sync fails to bring its drawing down
- **Then:** the board isn't in the list, the list says boards aren't syncing, a link to it says its drawing hasn't come down, and the next good sync puts it in the list with its ink

---

### User Story 1109:

- **Summary:** A board's folds, cards and Larry's names reach every device with its ink
- **Issues:** bead context-grabber-cc75 step 2 (the architecture review, 2026-11-21: a board's meaning lived only on the iPad that drew it, so the iPhone, the Mac and a reinstalled iPad saw the ink without the folds, the cards, or the names Larry knows the strokes by)
- **Status:** not implemented; asks: bead context-grabber-cc75 step 2 (proposed, waiting on Igor's decision to sync the meaning and on the CloudKit production-schema deploy for TestFlight builds)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board's meaning goes through iCloud with its ink*

#### Use Case:
- **As someone** who draws on the iPad and looks at boards on the iPhone and the Mac
- **I want to** see a board on every device the way the iPad shows it, folds, headers, question cards and Larry's groups included
- **so that** a board means the same thing wherever I open it, and Larry's names for its strokes survive a reinstall

#### Acceptance Criteria:
- **Scenario:** The meaning arrives with the ink
- **Given:** a board drawn on the iPad with a folded header, a question card and a kept text of Larry's
- **When:** the iPhone syncs and I open the board there
- **Then:** the header is folded, the card and the text are there, and Larry's text keeps its name
