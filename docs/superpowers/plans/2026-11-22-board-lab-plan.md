# Plan: the Board Lab, a small app that opens the board alone for the whiteboard's UI tests

Bead context-grabber-09tx (whiteboard refactor D3 slice 4, under context-grabber-wq2j); story 1501. iPad simulator only
(Igor, 2026-11-22: no iPhone runs while the whiteboard work is in progress).

## Why

The 22 whiteboard UI test classes launch the whole app: `AppModel` (database, places, chat, call, archive, the mirror,
the daily strip, BugKit's delivery), the home window, and on activation the launch's grabs. Then each test opens the
boards list through the `GRABBER_WHITEBOARD=open` hook and taps through to its board. The UI test ledger
(`native/Build/logs/ui-timings.jsonl` in every pool slot, 3,940 cases up to 2026-11-23) says where a case's time goes.

## Before (the ledger, indicative: mixed runs, passed cases, retries included)

| Class | Cases | Median case (s) | Median launch (s) | Of it, waiting for the app to idle (s) | Class (s) |
|---|---|---|---|---|---|
| WhiteboardEraserUITests | 2 today (9 names over its history) | 31.2 | 7.2 | 4.0 | ~62 |
| WhiteboardTitleRenameUITests | 2 | 13.4 | 4.9 | 3.6 | ~27 |
| All 22 whiteboard classes | ~98 | 13-37 | 4.9-7.8 | 1.9-5.3 | ~2,300 |

Launch is 5-8 s of a 13-37 s case. Part of it is XCUITest's own (setting up the automation session, finding the app)
and stays whatever the app is. The part the app owns is the idle wait and what it does before the first screen settles.
Story 672 already found that the paper classes' time is mostly their own drawing and waiting, not launches.

## The design

- **A second app target, `BoardLab`** (XcodeGen, `native/project.yml`): the app's own sources (`App/` and `Shared/`)
  minus its `@main`, plus `native/BoardLab/`, its own `@main`. It makes the same `AppModel` (the board's view
  needs it), so the board is the app's board, but its only window is the boards list. There is no home window, no
  mirror on screen, and no scene-phase work, so no launch grab and no foreground refresh. Its own bundle id
  (`com.idvorkin.grabbernative.boardlab`) and display name, iPad only, no widgets, share extension or entitlements.
- **What it opens on**: the boards list, as `GRABBER_WHITEBOARD=open` does today; a board from the launch hooks it
  shares with the app (`GRABBER_BOARD_FIXTURE` and the rest); and a recorded Cockpit session.
  `GRABBER_LAB_SESSION=<name>` asks the fake Cockpit to play that session (story 1174) on the first board message the
  lab sends, so Larry answers as he did that day.
- **`BoardLabUITests`**, a UI test bundle whose target app is the lab. A moved class's file stays in
  `native/UITests/`: it leaves `GrabberNativeUITests`' sources and joins the lab's, with the helpers it needs.
  The test code doesn't change, since `XCUIApplication()` is whichever app the bundle targets.
- **At most two classes move in this PR**, as proof: `WhiteboardEraserUITests`, which launches three times in two
  cases (one relaunches to check what a launch keeps), and `WhiteboardTitleRenameUITests`, which uses the board
  fixture hooks. Both run on the iPad
  simulator through the wrapper, in a build lane. The GrabberNative scheme's test action holds both bundles, so
  `scripts/native/test-whiteboard-ui.sh` and the ladder run a lab class with the `BoardLabUITests/` prefix in the
  same xcodebuild.

## Trade-offs

| | Board Lab target (this plan) | Same app, a "board only" launch mode | No change |
|---|---|---|---|
| Launch saving | home window and scene-phase work skipped | the same | none |
| Build cost | a second app: `App/` compiled again for it (measured below) | none | none |
| Isolation | own bundle id, own defaults and container: no state leaks from the app's tests | shares the app's | n/a |
| Risk | a launch path the phone never runs; drift is caught because it builds the same sources | a test-only branch in the app's `@main` | n/a |

## The numbers that decide it (measured 2026-11-22, iPad Pro 11-inch (M5) simulator, lane 1, the same simulator)

The two classes ran three times each way through `xcodebuild-log.sh`: first in the app (main's project), then in the
lab. All 24 cases passed.

| | Before (app) | After (lab) | Change |
|---|---|---|---|
| The two classes, seconds per run (sum of cases, 3 runs) | 87.6, 85.8, 85.1 (median 85.8) | 81.1, 83.6, 79.2 (median 81.1) | -4.7 s (-5.5%) |
| xcodebuild wall seconds per run | 92, 91, 99 | 86, 100, 84 | median -6 s |
| Median case (s) | 24.2 | 22.9 | -1.2 s per case |
| Median launch_s per case | 5.48 | 4.97 | -0.5 s per launch |
| Each case, median of 3 (s): rename / eraser kept / other device's name / eraser after the report sheet | 22.6 / 31.8 / 7.1 / 25.2 | 20.0 / 29.6 / 6.2 / 23.6 | -1 to -2 s each |
| Build for testing, the lab after its build folder was removed (s) | - | 10 | +10 once |
| Build for testing after one board file changed (s) | app 10 | lab 4 | +4 per build |
| The scheme's build for testing with both bundles, nothing changed (s) | - | 8 | |

**Reading it.** The lab saves about 1.2 s a case, and only a little of that is the launch itself: XCUITest's own launch
steps stay. The rest is quicker steps once the app is up (no home window behind the board, no scene-phase work). Its
build cost is a few seconds per build, because Xcode's compile cache shares the app's compiled files. For the ~98
whiteboard cases a full suite run would save about 2 minutes for about 4 s more build. So the net is positive but
small, about 5%. It is not the big win a launch-bound suite would get, and the whiteboard's time is its own drawing and
waiting (story 672).

**Go or no-go: a small go.** Moving the rest is worth about 2 minutes a full run. It waits on `PaperScreen` getting a
file of its own (bead context-grabber-wv1e), and the lead decides whether those minutes are worth 20 file-membership
moves. The bigger reason to keep the lab is the one the numbers don't show: it opens a board on a recorded session for a
demo or a test.

## Not in this PR

- Seeding the board's ink from a recorded session's snapshot. The session plays Larry's side only, and the board
  starts empty or from the fixture hooks. Bead context-grabber-j811 holds this.
- Moving the other 20 classes. Many need the `PaperScreen` helper, which lives in `WhiteboardPaperGhostsUITests.swift`.
  Two open PRs edit that file, so it moves to a file of its own after they land. Until then the lab bundle compiles
  that file too.
