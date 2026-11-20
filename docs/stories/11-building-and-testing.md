# Building and testing

How a change gets from a commit to Igor's phone quickly, without giving up the evidence that it works. Written for this
app and meant to be shared with Igor's other apps once it has proved itself here.

The numbers these stories start from (2026-11-04, the whiteboard's UI tests on the iPhone 17 simulator): 56 tests in
about 25 minutes, one at a time, about 27 seconds each. Almost none of that is compiling or moving between tests. Of the
steps timed, about a third is waiting for the app to go idle, a fifth starting and stopping the app, a fifth finding
things on screen, and a sixth waiting for things to appear.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 670:

- **Summary:** Most of what a change needs proved is proved on the Mac, in seconds
- **Status:** not implemented; bead `context-grabber-3k6`. Moved to host tests so far, each with the UI or smoke checks that only repeated it cut: the whiteboard turn's rules (`WhiteboardGhostTurnsTests`, [3985337](https://github.com/idvorkin/context-grabber/commit/3985337)), the whiteboard's persistence policy (`BoardKeepingTests`, [f41be39](https://github.com/idvorkin/context-grabber/commit/f41be39)), the Inbox's send orchestration (`InboxOutboxTests`, [845a6f2](https://github.com/idvorkin/context-grabber/commit/845a6f2)) and the chat archive and new-thread rules (`ChatArchiverTests`, `ChatNewThreadScreenTests`, [23dd212](https://github.com/idvorkin/context-grabber/commit/23dd212)); verified together at [f83889f](https://github.com/idvorkin/context-grabber/commit/f83889f) on the Mac host (rung 1, 1,123 ContextCore tests) and the simulator (rung 2: the whiteboard and chat UI suites and the smoke). The duplicates the 2026-11-12 assessment found: story 770

#### Use Case:
- **As Igor,** waiting for a fix to reach his phone
- **I want to** have each rule tested on the Mac, in a library with no simulator, and keep the simulator for what only a real screen can show
- **so that** a change is proved in seconds, and the simulator's queue stays short

#### Acceptance Criteria:
- **Scenario:** A rule that needs no screen
- **Given:** a UI test whose check does not depend on a real view, gesture or system service
- **When:** the test is reviewed
- **Then:** its check moves to a host test, and the UI test is deleted or shrinks to what only the screen can show

---

### User Story 671:

- **Summary:** My other apps share the testing tools instead of each growing its own
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** with several apps on one Mac
- **I want to** have the test helpers and the practice that worked here available to my other apps
- **so that** a speedup found in one app reaches the rest, and no app solves it again

#### Acceptance Criteria:
- **Scenario:** A practice that has proved itself here
- **Given:** a testing helper or practice has shortened this app's runs, with the measurement to show it
- **When:** another app starts its testing work
- **Then:** it can take the helper from the shared library and read the practice in the shared practices for every app

---

### User Story 672:

- **Summary:** UI tests keep the app open unless a restart is the point
- **Status:** started: `ChatArchiveUITests` shares one running app in [9fd6dbe4](https://github.com/idvorkin/context-grabber/commit/9fd6dbe4) and [3edeacae](https://github.com/idvorkin/context-grabber/commit/3edeacae) and goes back to the list by its own Back, verified on the simulator (iPhone 17, 2026-11-11: three tests, one launch, 26 s against 56-70 s relaunching each). A link home as the reset was tried first and dropped: XCTest waited 33 s for the app to idle after it. The other classes follow one at a time, each measured: `ChatSkillThreadUITests` shares one too in [9c2c9834](https://github.com/idvorkin/context-grabber/commit/9c2c9834) (iPhone 17, 2026-11-11: two tests, 22 s against 27 s). The whiteboard's paper classes stay as they are: `WhiteboardPaperLinesUITests` shared saved 11 s of 191 s, as their time is their own drawing and waiting, not launches, and a keyboard left up (#850) carried into the next test; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have UI tests share a running app and move it to the state each one needs
- **so that** the run doesn't spend minutes starting and stopping the app

#### Acceptance Criteria:
- **Scenario:** A test that isn't about restarting
- **Given:** a UI test that doesn't check what survives a restart
- **When:** it begins after another test
- **Then:** it runs in the already open app, starting from the same clean state a fresh launch would give it

---

### User Story 673:

- **Summary:** A test checks for what it needs without a fixed wait
- **Status:** partly implemented in d91ca4d, 2e67445, 2fcd476: the UI tests wait with `appears(within:)`, verified on the simulator (rung 2, the board suite 63 tests in 1621 s, chat 22 of 22); on branch `native/673-waits` the whiteboard's waits for the save (the page number's *saved* value) and for ink to settle on screen replace 11 fixed pauses, verified on the simulator (2026-11-10: all 30 whiteboard tests pass in a ladder climb, 545 s against 661 s for the run before it; the four save waits pass alone on the iPad; PhoneBoardsUITests passes alone, its failure in the climb's order is #868); the rest remain: a new board settling (tangled with #850), a wait that proves nothing happened, and pauses before a screenshot kept for a person; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have tests move on as soon as what they're waiting for is there
- **so that** looks that come a second late, and pauses of a set length, stop adding up to minutes

#### Acceptance Criteria:
- **Scenario:** The thing is already on screen
- **Given:** a UI test is waiting for something already on screen
- **When:** it checks
- **Then:** it moves on in well under a second

---

### User Story 674:

- **Summary:** After the pipeline, only what its changes touched runs again
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting for a ready PR to merge
- **I want to** have the last check before merging rerun only the tests a pipeline's changes could affect
- **so that** a change to a doc comment doesn't cost another full run

#### Acceptance Criteria:
- **Scenario:** The pipeline touched one test and a comment
- **Given:** the whole suite passed before the pipeline ran
- **and Given:** the pipeline changed only documents, comments and one test class
- **When:** the check before merging runs
- **Then:** it runs that test class, says what it skipped and why, and the PR's comment names the rung

---

### User Story 675:

- **Summary:** The most urgent work goes first on the simulator
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting for something he asked for
- **I want to** have a ready PR's last check run ahead of exploratory runs and repeats
- **so that** a fix one check away from my phone doesn't wait behind a test being repeated

#### Acceptance Criteria:
- **Scenario:** Two runs waiting on the one simulator
- **Given:** a ready PR's last check and an exploratory run are both waiting
- **When:** the simulator comes free
- **Then:** the PR's check runs first

---

### User Story 676:

- **Summary:** A full whiteboard run takes under ten minutes
- **Status:** not implemented; bead `context-grabber-3k6`; ten minutes is a proposed target, Igor's to change

#### Use Case:
- **As Igor,** deciding whether a whiteboard change is safe
- **I want to** have the whole whiteboard suite finish in under ten minutes
- **so that** running it is an easy choice rather than a half-hour wait

#### Acceptance Criteria:
- **Scenario:** A full run on an idle Mac
- **Given:** nothing else is using the simulator
- **When:** the full whiteboard suite runs
- **Then:** it finishes in under ten minutes and proves every behaviour the 25-minute suite proved, on the simulator or on the Mac

---

### User Story 683:

- **Summary:** One command climbs the test ladder, cheapest rung first, and stops at the first failure
- **Status:** implemented in 735f6b4, e1dde12; the lint, host and simulator rungs ran for real on 2026-11-05 (rung 2 on one chat class: build 34 s, `ChatArchiveUITests` 7 of 7 in 198 s, the project generated first); the Mac rung has run only in dry runs; bead `context-grabber-3k6`; [spec](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As Igor,** waiting to know whether a change is safe
- **I want to** run one command that tries the cheapest checks first and only goes on to the simulator tests this change touches
- **so that** a mistake shows up in seconds, and a change to one screen doesn't cost a half-hour run

#### Acceptance Criteria:
- **Scenario:** A change to the chat screen, and a failure on a cheap rung
- **Given:** the branch changed only chat's code
- **and Given:** the Mac build fails on it
- **and Given:** no other Xcode build is running
- **When:** the ladder runs
- **Then:** it stops at the Mac rung without starting the simulator, printing the seconds for each rung and that it stopped on the Mac

---

### User Story 686:

- **Summary:** A change to one screen runs that screen's own UI tests
- **Status:** implemented in 0712a24, 0e7e7b1; verified on the host rung (`scripts/native/test-ladder-map.sh`)
- **Issues:** [#795](https://github.com/idvorkin/context-grabber/issues/795)

#### Use Case:
- **As Igor,** changing one screen of the app
- **I want to** have the ladder run that screen's own UI tests
- **so that** the change is checked on the simulator before it reaches my phone, without the forty-five minutes of every test

#### Acceptance Criteria:
- **Scenario:** A change to the Gym Timer
- **Given:** the branch changed only the Gym Timer's code
- **When:** the ladder reaches the simulator rung
- **Then:** it runs the Gym Timer's own UI tests and no other screen's, naming them before it starts

---

### User Story 687:

- **Summary:** A change to a screen no simulator test opens is named, not passed over
- **Status:** implemented in 0712a24, 0e7e7b1; verified on the host rung (`scripts/native/test-ladder-map.sh`)
- **Issues:** [#795](https://github.com/idvorkin/context-grabber/issues/795)

#### Use Case:
- **As Igor,** reading what the ladder checked
- **I want to** be told when a change got no UI tests of its own
- **so that** a green run is never mistaken for a tested screen

#### Acceptance Criteria:
- **Scenario:** A change to the iPad's windows
- **Given:** the branch changed only the iPad's windows, which no simulator UI test opens
- **When:** the ladder runs
- **Then:** it chooses no UI tests for that change, names the changed file, and says how to run every UI test

---

### User Story 745:

- **Summary:** Every UI test run says where its time went
- **Status:** implemented in 28af189; verified on the host rung (`scripts/native/test-ui-timings.sh`, against a real whiteboard run's log)
- **Issues:** [#826](https://github.com/idvorkin/context-grabber/issues/826)

#### Use Case:
- **As Igor,** waiting on slow simulator runs
- **I want to** see, after every UI test run, how long each test took and how much of that was launching the app, retried steps and waiting
- **so that** we speed up the part that actually costs the time, and can tell whether a change helped

#### Acceptance Criteria:
- **Scenario:** A UI test run finishes
- **Given:** a run of one or more UI test classes on the simulator
- **When:** its tests have finished, passed or failed
- **Then:** the run prints the slowest tests, each class's total and launch time, and the kinds of wait that cost the most, and keeps one line per test that later runs can be compared against

---

### User Story 750:

- **Summary:** A box with no Mac checks the whole app's Swift before anything reaches the Mac
- **Status:** implemented in [97a0b57](https://github.com/idvorkin/context-grabber/commit/97a0b57); verified on the Linux rung (`just test-linux` on aarch64 Ubuntu: 1,185 tests, the three cross-builds, the app's sources for iOS and the three script checks all ok); the Mac's own rungs are unchanged; a missing kept build directory created in [7dae5d56](https://github.com/idvorkin/context-grabber/commit/7dae5d56) (#904), verified on the host rung by running the new block alone: a relative path not yet there made and resolved against the caller, an uncreatable one stops with exit 2 naming it; the full Linux rung was not run, as this Mac has no Linux box
- **Issues:** the test-ladder audit of 2026-11-10 ("Linux as a real rung"); [#904](https://github.com/idvorkin/context-grabber/issues/904) (a kept build directory that did not exist yet failed the rung)

#### Use Case:
- **As Igor,** with agents working on Linux boxes while the Mac is busy or locked
- **I want to** have every change compiled and host-tested off the Mac first, app code included
- **so that** a type slip in a view or a broken ladder map shows up on the agent's box in minutes, not in the Mac's build an hour later

#### Acceptance Criteria:
- **Scenario:** An agent on Linux changes app code and a host test
- **Given:** a Linux box with the Swift toolchain and the Darwin SDK, and no Mac
- **When:** the agent runs the Linux rung
- **Then:** ContextCore's tests run, the package and the app's sources (the app, the widgets, the share extension and the UI tests) are compiled for Apple, the ladder's map is checked, and each step says ok, failed or skipped and why

- **Scenario:** An agent keeps the rung's build between runs in a folder that does not exist yet
- **Given:** a build directory to keep, named by a path that is not there yet (relative to where the agent stands, or absolute)
- **When:** the agent runs the Linux rung
- **Then:** the folder is made and used, and when it cannot be made the rung stops at once, saying which folder and that it could not create it

---

### User Story 688:

- **Summary:** A new branch builds in a worktree that already has a build
- **Status:** implemented in 0e0cf96; verified on the Mac rung (a slot returned and re-leased for a new branch rebuilt in 7 s with one file touched, against 39 s for its first build)
- **Issues:** [#803](https://github.com/idvorkin/context-grabber/issues/803)

#### Use Case:
- **As Igor,** with several agents each working on a branch of its own
- **I want to** have a new branch start in a worktree that was built before
- **so that** its first build takes the time of what changed, and build folders stop filling the disk

#### Acceptance Criteria:
- **Scenario:** A second branch in a returned worktree
- **Given:** a pool worktree was built for one branch and returned
- **When:** an agent leases it for a new branch and builds for the simulator
- **Then:** the build reuses what the earlier one compiled, and the Mac holds no more build folders than the pool has worktrees

---

### User Story 689:

- **Summary:** A stuck or flaky UI test costs a minute or two, not a whole rerun
- **Status:** implemented in 4337f19; verified on the host by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild: the time limit, the retry, the stopped hang, a retry printing past the idle limit) and `scripts/native/test-ui-timings.sh` (a retried case named); the hang wait cut from 30 s to 10 s in e427499 (retries run before the one closing suite line, so the cut skips only xcodebuild's idle tail), verified on the host by the same check
- **Issues:** the pipeline timing study of 2026-11-10 (Igor: "I don't want to be spending 20 minutes in the simulator"; "fix all the issues")

#### Use Case:
- **As Igor,** waiting on a change to reach the phone
- **I want to** have a UI test that hangs or fails once cost little, while still being told about it
- **so that** one flaky case doesn't buy another 10-minute pass of the whole list

#### Acceptance Criteria:
- **Scenario:** A UI test run on the simulator
- **Given:** a run where one case fails once and passes on a second try, one case runs past two minutes, and xcodebuild sits idle after the last suite closes
- **When:** the run ends
- **Then:** the failed case alone ran again and the run's timing summary names it as passed only on retry, the long case failed at two minutes, and xcodebuild was stopped 10 s after the suite closed with the log's result kept

---

### User Story 782:

- **Summary:** The simulator rung keeps the Mac's display on, and refuses a locked screen at once
- **Status:** implemented in c58dba5; verified on the host by `scripts/native/test-ladder-map.sh` (fake `caffeinate` and lock probe: rung 2 runs under `caffeinate -d -i` after a `caffeinate -u`, the Mac rung under `-i` alone, and a locked screen stops rung 2 with exit 75 before anything builds); not yet seen on a real dark Mac
- **Issues:** the fast-sim-tests study of 2026-11-16 (the 915 run's whiteboard step: 29 minutes, 17 of them waiting for a dark, locked screen; a run that morning, two hours)

#### Use Case:
- **As Igor,** away from the Mac while a change climbs the ladder
- **I want to** have the simulator rung keep the display lit, and refuse straight away when the screen is already locked
- **so that** a run that takes 11 to 14 minutes doesn't take 30 minutes or two hours, and a locked Mac costs seconds and says why, not an hour of the build lock

#### Acceptance Criteria:
- **Scenario:** Starting the simulator rung
- **Given:** the Mac's display may be asleep, and its screen may be locked
- **When:** the ladder starts rung 2
- **Then:** it wakes the display and holds it on for the whole rung, and if the screen is locked it stops with exit 75 and *the Mac's screen is locked: UI tests don't start on a locked screen*, building nothing

---

### User Story 783:

- **Summary:** A UI test run that never starts is stopped in three minutes, naming the likely cause
- **Status:** implemented in c58dba5; verified on the host by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild that never starts a suite is stopped and exits 75 with the message; one that compiles first, a build, and a run that starts in time are left alone)
- **Issues:** the fast-sim-tests study of 2026-11-16 (the only bound on a run that never started was the rung's 60-minute limit)

#### Use Case:
- **As Igor,** waiting on a UI test run
- **I want to** have a run whose first test hasn't started within three minutes stopped and blamed on the likely cause
- **so that** a dark or locked screen costs three minutes and a clear line, not a quarter of an hour or the whole time limit

#### Acceptance Criteria:
- **Scenario:** A run of built tests that doesn't start
- **Given:** a test run of an existing build, with no test suite started 180 s after xcodebuild began
- **When:** the 180 s pass
- **Then:** xcodebuild is stopped and the run fails with exit 75, saying no test started, that UI tests don't start with the display asleep or the screen locked, and whether the screen is locked now; a run that compiles first, or starts in time, runs on

---

### User Story 784:

- **Summary:** A change to one of the board's own view files runs only the UI test classes that open it
- **Status:** implemented in 1f27906 and 9d8c81c for the one such file on main, the board fixture hook (`WhiteboardRowDeleteUITests` and `ChatImageUITests`, where it ran all eight whiteboard classes and missed the chat one); verified on the host by `scripts/native/test-ladder-map.sh`. The board's two big views (the board and its paper) draw every board and still run every class. The view files on branches tonight get their rows as they land: the name in the bar (`WhiteboardRowDeleteUITests`), the panel's newest line (`WhiteboardTurnUITests`). The question cards (#919) have theirs: their two view files and their rules in `ContextCore` run `WhiteboardQuestionUITests` alone, and that class joined the whiteboard's list, which the map's check now holds to every `Whiteboard*UITests` class in the tree
- **Issues:** the fast-sim-tests study of 2026-11-16 (any view file ran all eight whiteboard classes, 11 to 14 minutes)

#### Use Case:
- **As Igor,** waiting on a fix to one small part of the board
- **I want to** have the simulator run the classes that open that part, not every whiteboard class
- **so that** a one-file view fix costs a minute or two of UI tests, not the whole whiteboard step

#### Acceptance Criteria:
- **Scenario:** A change to the board fixture hook
- **Given:** a branch that changes only the app's board fixture hook
- **When:** the test ladder climbs
- **Then:** the simulator runs the row-delete class and chat's picture-from-a-board class and no other whiteboard class, while a change to the board's own view still runs every whiteboard class, and `--full` still runs the whole suite

---

### User Story 753:

- **Summary:** A change to one whiteboard rule runs only the whiteboard tests that show it
- **Status:** implemented in 1107aad; verified on the host by `scripts/native/test-ladder-map.sh` (the paste, ghost and board-list rules, and the hooks running every class)
- **Issues:** the pipeline timing study of 2026-11-10 (any whiteboard file ran all 8 classes, 9–11 min)

#### Use Case:
- **As Igor,** waiting on a whiteboard fix to reach the iPad
- **I want to** have the simulator run only the whiteboard tests a change can break
- **so that** a change to how a paste is laid out doesn't cost a 10-minute pass of every board test

#### Acceptance Criteria:
- **Scenario:** A change to the paste rule
- **Given:** a branch that changes only how a paste is laid out on a board
- **When:** the test ladder climbs
- **Then:** the simulator runs the two paste test classes and no other whiteboard class, while a change to the board's own views or its launch hooks still runs every whiteboard class

---

### User Story 756:

- **Summary:** A change to the picture's frame, Larry's clock or the note runs only the turn and ghosts tests
- **Status:** implemented in [2b6dade](https://github.com/idvorkin/context-grabber/commit/2b6dade); verified on the host by `scripts/native/test-ladder-map.sh` (each of the three rules alone selecting the turn and the ghosts-on-paper classes)
- **Issues:** the pipeline timing study of 2026-11-10 (any whiteboard file ran all 8 classes, 9–11 min)

#### Use Case:
- **As Igor,** waiting on a fix to Larry's turn to reach the iPad
- **I want to** have the simulator run only the classes that show the picture's frame, Larry's clock and the note
- **so that** such a change doesn't cost a pass of every board test (story 753)

#### Acceptance Criteria:
- **Scenario:** A change to the picture's frame
- **Given:** a branch that changes only where Larry's picture is framed on the board
- **When:** the test ladder climbs
- **Then:** the simulator runs the turn and the ghosts-on-paper classes and no other whiteboard class (it ran all 8)

---

### User Story 754:

- **Summary:** UI tests don't wait for screens to slide
- **Status:** implemented in ed896a9 and be6e45f; verified on the simulator (iPhone 17, 2026-11-10): the chat suite's 16 tests went from about 243 s to 193 s, all passing; the whiteboard's classes keep their animations, as PaperLines on the iPad simulator counted a second stroke after the Board menu without them (the menu's closing tap reaching the canvas), until #850 is settled

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have the app under UI test skip its sliding and fading animations
- **so that** each step stops waiting out an animation nobody is watching, and a whiteboard pass gets shorter

#### Acceptance Criteria:
- **Scenario:** A UI test opens a screen and a menu
- **Given:** any UI test but the whiteboard's, launched the way every UI test launches the app
- **When:** it pushes a screen, opens a sheet or a menu
- **Then:** the screen, sheet or menu is there at once rather than after its animation, and the app the phone runs is unchanged

---

### User Story 755:

- **Summary:** One climb of the ladder runs the touched UI tests and the smoke on one build and one boot
- **Status:** implemented on branch `native/755-ladder-smoke`; verified by the ladder's map self-test (host: the smoke runs on the rung's build and simulator; a Gym Timer file maps to the timer section, a UI test file to none, shared code to all) and one real climb (iPhone 17, 2026-11-10: `--rung 2 --changed` a Gym Timer file built once, ran its two classes in 62 s, then the timer smoke on the same boot in 60 s, 145 s in all)

#### Use Case:
- **As Igor,** waiting on a change's simulator check
- **I want to** have the ladder run the smoke's touched sections right after the touched UI test classes, on the build and the simulator it already has
- **so that** a change pays for one simulator build, one boot and one wait for the build lock, not two

#### Acceptance Criteria:
- **Scenario:** A change to one feature
- **Given:** a branch that changes the Gym Timer's screen
- **When:** I run `just test-ladder`
- **Then:** rung 2 builds once, runs the timer's UI test classes, then the smoke's timer section on the same booted simulator, times each step, and stops at the first failure; `--dry-run` names the smoke's sections; `LADDER_SMOKE=0` leaves the smoke out

---

### User Story 770:

- **Summary:** A UI test that only repeats a host test or another UI test is cut, after the host test is seen to fail
- **Status:** implemented in [ebc153f](https://github.com/idvorkin/context-grabber/commit/ebc153f), [49d577c](https://github.com/idvorkin/context-grabber/commit/49d577c), [4abeb11](https://github.com/idvorkin/context-grabber/commit/4abeb11); verified on the host: before each delete the rule it held was broken by a one-line change and the host test that guards it was seen to fail, then the source restored (the mutations are in the PR). Where no host test held the rule it moved into `ContextCore` first (why a board can't open, what a table reads aloud), with host tests. The rest of the same trim is stories 757–759, 780 and 781
- **Issues:** the simulator assessment of 2026-11-12 (`~/tmp/agent/notes/2026-11-12-sim-tests-down-the-ladder.md`); story 670

#### Use Case:
- **As Igor,** waiting on a whiteboard or chat change to reach the iPad
- **I want to** have the simulator run each rule once, where only a screen can show it
- **so that** a whiteboard pass costs about a minute and a half less, without a rule losing its test

#### Acceptance Criteria:
- **Scenario:** A UI test that repeats a host test
- **Given:** a UI test whose rule a host test already holds
- **When:** the rule is broken in the source by one line
- **Then:** the host test fails, and only then is the UI test deleted; when no host test fails, a host test is written first or the UI test stays

---

### User Story 757:

- **Summary:** Two UI tests that check one screen share a launch
- **Status:** implemented in [ebc153f](https://github.com/idvorkin/context-grabber/commit/ebc153f) (the whiteboard's two ghost tests in one launch, the colours test checking one colour, Larry's marks without a reopen); verified on the host only (the UI tests typecheck); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code
- **Issues:** the simulator assessment of 2026-11-12; story 770

#### Use Case:
- **As Igor,** waiting on a whiteboard change's simulator pass
- **I want to** have checks of the same screen made in one launch of the app
- **so that** a launch, the slowest step of a UI test, is paid once per screen and not once per check

#### Acceptance Criteria:
- **Scenario:** Two UI tests that open the same screen
- **Given:** two UI tests that each launch the app to check one thing on the same screen
- **When:** they are merged
- **Then:** one launch makes every check both made, in the order the screen allows

---

### User Story 758:

- **Summary:** What an iPhone does with boards is read from the smoke's log, not from a test class of its own
- **Status:** implemented in [c9ec172](https://github.com/idvorkin/context-grabber/commit/c9ec172) and the review fix after it (the list's New board and the log's `new_board` read one rule); verified on the host (`BoardIndexTests`: a phone starts no board, draws on none, and the bar says to draw on the iPad; `scripts/native/test-ladder-map.sh`: a whiteboard change runs no iPhone class); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code. The Board menu, the ghosts button and Larry's turn are in the bar only on a board the log calls `editable`, so the smoke's `editable` false stands for them. No test looks at the phone's screen for the missing buttons any more, only at the rules they read, and *Send to Larry* still being there on a phone has no test
- **Issues:** the simulator assessment of 2026-11-12; stories 746, 770

#### Use Case:
- **As Igor,** waiting on a whiteboard change, whose UI tests run on an iPad simulator
- **I want to** have the iPhone's look at boards judged in the smoke's launch on the iPhone simulator
- **so that** a whiteboard change doesn't boot a second simulator for one class (about 65 s)

#### Acceptance Criteria:
- **Scenario:** The iPhone's look at the boards
- **Given:** a whiteboard change, whose UI test classes run on an iPad simulator
- **When:** the ladder climbs
- **Then:** what an iPhone does with boards (no New board, its own board look-only with the bar's reason) is read from the smoke's session log on the iPhone simulator it already booted, rather than from a class of its own in a second test session

---

### User Story 759:

- **Summary:** The minute-long Health session runs for a Health change, not a breathing change, and stops waiting for a sheet that isn't coming
- **Status:** implemented in [dc31beb](https://github.com/idvorkin/context-grabber/commit/dc31beb); verified on the host (`scripts/native/test-ladder-map.sh`: breathing code doesn't select `BreatheMindfulUITests`, the Health source does); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code
- **Issues:** the simulator assessment of 2026-11-12; stories 242, 770

#### Use Case:
- **As Igor,** waiting on a change to the breathing screen
- **I want to** have the session that writes to Health run only when the Health code changes
- **so that** a breathing change is about 160 s shorter, and the write to Health is still checked when it can break

#### Acceptance Criteria:
- **Scenario:** A breathing change and a Health change
- **Given:** a branch that changes the breathing screen, and another that changes how the app writes to Health
- **When:** the ladder climbs each
- **Then:** the breathing change runs the breathing classes without the minute-long Health session, the Health change runs that session, and the session's wait for Health's sheet ends as soon as Today's cards show

---

### User Story 780:

- **Summary:** A chat change runs no check that belongs to the whiteboard or to a host test
- **Status:** implemented in [49d577c](https://github.com/idvorkin/context-grabber/commit/49d577c), [4abeb11](https://github.com/idvorkin/context-grabber/commit/4abeb11); verified on the host (`BoardIndexTests`: why a board can't open; `ChatTablesTests`: what a table reads aloud; `scripts/native/test-ladder-map.sh`); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code. The table's label inside the bubble's combined label has no simulator check
- **Issues:** the simulator assessment of 2026-11-12; story 770

#### Use Case:
- **As Igor,** waiting on a chat change's simulator pass
- **I want to** have the chat classes hold only what a chat screen alone can show
- **so that** a chat pass is about half a minute shorter

#### Acceptance Criteria:
- **Scenario:** A chat change
- **Given:** a branch that changes the chat screens
- **When:** the ladder climbs
- **Then:** the chat classes run without a check that is whiteboard code (a link to a missing board) or a host test's (what a table reads aloud), and the picture's two ways out and the bar's mic share one launch each with the tests that already open those screens

---

### User Story 781:

- **Summary:** A metric's detail, the blog's tiles and the strip's sheets are each checked in fewer launches
- **Status:** implemented in [49d2901](https://github.com/idvorkin/context-grabber/commit/49d2901); verified on the host only (the strip's rules are `CounterWeekTests`; the UI tests typecheck); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code
- **Issues:** the simulator assessment of 2026-11-12; story 770

#### Use Case:
- **As Igor,** waiting on a change to the mirror
- **I want to** have each screen's checks made in as few launches as the screen allows
- **so that** the mirror's UI tests stop paying a launch per check

#### Acceptance Criteria:
- **Scenario:** A screen's checks in one launch
- **Given:** a metric's detail, the blog's three tiles and the daily strip's press-and-hold sheets, each with its rules on the host
- **When:** their UI tests run
- **Then:** the detail's form, the report over it and its close are one launch; the three tiles are one launch that comes back from Safari between them; and each strip sheet makes one round of edit and save

---

### User Story 827:

- **Summary:** The smoke skips its audio checks on a locked Mac, and says so
- **Status:** implemented on branch `native/batch-decided-1114`; verified by the script check `scripts/native/test-smoke-lock.sh` in `just native-test` (the lock probe faked); a real smoke run on a locked Mac still to do
- **Issues:** [#419](https://github.com/idvorkin/context-grabber/issues/419) (a locked Mac starves the simulator's audio); Igor, 2026-11-14: skip them rather than rerun for 5 to 12 minutes

#### Use Case:
- **As Igor,** waiting on a simulator run while the Mac's screen has locked
- **I want to** have the audio checks skipped and named as skipped
- **so that** a locked screen doesn't fail the run and cost a rerun, and a skipped check is never read as a pass

#### Acceptance Criteria:
- **Scenario:** A smoke run on a locked Mac
- **Given:** the Mac's screen is locked
- **When:** the simulator smoke reaches the timer, breathing and the real-audio call
- **Then:** each prints *skipped: Mac screen locked* and doesn't run, the run's last lines count them as skipped and not passed, and unlocked they run as before

---

### User Story 828:

- **Summary:** A report of how long a change takes, from the repo
- **Status:** implemented on branch `native/batch-decided-1114`; run once by hand against GitHub and the deploys ledger, writing to a scratch folder; no automated check (it reads live GitHub)
- **Issues:** the lead-time study of 2026-11-14

#### Use Case:
- **As Igor,** wanting to know where a change's time goes, week after week
- **I want to** run one recipe that reads the merged PRs and the deploys and writes the lead-time page
- **so that** the report outlives the scratch folder it was born in, and nothing private goes into the public repo

#### Acceptance Criteria:
- **Scenario:** Running the report
- **Given:** `gh` is signed in and the deploys ledger is where `LEAD_TIMES_DEPLOYS` says, or its default
- **When:** I run `just lead-times`
- **Then:** it writes `data.json` and `index.html` to the output folder, each PR's minutes from asked to merged to on a device, and nothing in the repo changes


---

### User Story 785:

- **Summary:** Up to four Mac and simulator jobs at once, as many as the Mac's memory allows
- **Status:** implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh` (the lane count from the memory and from `BUILD_LANES`, the first free lane's lock, lane N's simulator named and cloned once, the wait for other xcodebuilds per lane, one lane unchanged) and the ladder's map self-test (the simulator rung takes a lane's lock)
- **Issues:** #954 (Igor, 2026-11-19, on the M5 Pro MacBook Pro, 48 GB, 18 cores: "this machine has way more horsepower so you can run multi simulators", "we can run 4 builds at once on this machine")

#### Use Case:
- **As Igor,** with several agents fixing issues in parallel on a 48 GB Mac
- **I want to** have their Mac builds and simulator runs go side by side, up to what the Mac's memory holds, instead of queueing behind one lock
- **so that** an agent's simulator check waits for a free lane, not for every other agent's whole run, while a 16 GB Mac still runs one at a time

#### Acceptance Criteria:
- **Scenario:** The lane count
- **Given:** a Mac with 48 GB of memory and no `BUILD_LANES` set
- **When:** a Mac or simulator rung starts
- **Then:** the Mac has four build lanes (one for every 12 GB, at most four, at least one): one on a 16 GB Mac, and `BUILD_LANES` names any other number

- **Scenario:** A job takes the first free lane
- **Given:** four lanes, with lanes 1 and 2 busy
- **When:** a third agent's simulator rung starts
- **Then:** it runs at once in lane 3, says so, and uses lane 3's own simulators (*iPhone 17 lane 3*, *iPad Pro 11-inch (M5) lane 3*) and its own fake-server ports; when all four are busy it waits, for up to an hour, and the ladder counts that wait apart from the rung's own seconds

- **Scenario:** A lane's simulator, the first time
- **Given:** lane 3 has never run on this Mac
- **When:** its first job needs the iPhone simulator
- **Then:** *iPhone 17 lane 3* is made once as a copy of *iPhone 17*, taken while lane 1 is idle so the copy keeps Health access and the seeded data; `just native-sim-lanes` makes every lane's copies ahead of time

- **Scenario:** Other Xcode builds
- **Given:** four lanes and three other xcodebuilds running
- **When:** a simulator rung is about to start
- **Then:** it starts; with four others running it waits, and refuses after half an hour; on a one-lane Mac it waits for any other, as before

- **Scenario:** A one-lane Mac
- **Given:** a 16 GB Mac
- **When:** two agents start simulator rungs
- **Then:** the second waits for the first on the same lock as before lanes, older checkouts included, and runs on the same named simulators

---

### User Story 980:

- **Summary:** One booted simulator per build lane, left booted between runs
- **Status:** implemented in f63a8e0, d1e8e18; verified on the host by the ladder's map self-test (265 checks: the phone and the iPad booted with `bootstatus -b`, nothing shut down at the end) and on the simulator 2026-11-17 (rung 2, `--changed` WhiteboardTurnUITests and GymTimerUITests, twice in a row): the old scripts booted 3 times each run (236 s, 273 s), these 2 then 1 (240 s, 178 s); the second run found the iPad booted and used it with no boot (CoreSimulator.log, boots inside each rung's own window). Per lane (#954): implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh` (a busy lane's simulator left booted, the lane's other device and a simulator of no lane shut down, an idle lane's shut down only past the lane count, one lane shutting every other down as before)
- **Issues:** the boot-less brief of 2026-11-15 (Igor: "sure do it"); 31 boots on 2026-11-14, and the disk full of wallpaper snapshots on 2026-11-17; #954 (Igor, 2026-11-19, on the 48 GB M5 Pro: "we can run 4 builds at once on this machine")

#### Use Case:
- **As Igor,** running simulator checks many times a day, from several agents at once on a Mac with the memory for it
- **I want to** have the simulator a run used left booted for that lane's next run, and no more booted than the Mac has build lanes
- **so that** each run doesn't pay a boot's 300 MB of wallpaper snapshots that are never removed, its heat and its wait, and booted simulators never starve each other or get shut down under another job

#### Acceptance Criteria:
- **Scenario:** Two runs on one device
- **Given:** a simulator run that just passed or failed on the iPhone simulator of its lane
- **When:** the next run in that lane needs the iPhone simulator too
- **Then:** it finds it booted and uses it without a boot, and the simulator log shows no new boot

- **Scenario:** Another lane is busy
- **Given:** a Mac with four build lanes, and a job in lane 1 running its tests on the iPhone simulator
- **When:** a job in lane 2 boots its own iPhone simulator (*iPhone 17 lane 2*)
- **Then:** lane 1's simulator stays booted and its tests run on; lane 2's iPad, if booted, and any simulator that belongs to no lane are shut down first

- **Scenario:** More booted than there are lanes
- **Given:** a Mac with two build lanes, lane 2's job about to boot, and lane 1 idle with its simulator still booted from its last run, plus lane 3's from when the Mac had more lanes
- **When:** lane 2 boots its simulator
- **Then:** idle simulators are shut down until no more than two are booted, its own included, and a busy lane's never is

- **Scenario:** A one-lane Mac
- **Given:** a 16 GB Mac, or `BUILD_LANES=1`
- **When:** a job boots its simulator
- **Then:** every other booted simulator is shut down first, exactly as before lanes

---

### User Story 981:

- **Summary:** A climb on both the iPhone and the iPad switches device at most once
- **Status:** implemented in f63a8e0, d1e8e18; verified on the host by the ladder's map self-test (none booted: the phone, then the iPad; the iPad booted: the iPad, then the phone, the iPad shut first). verified on the simulator 2026-11-17: a second climb started on the iPad the first left booted (`rung 2 iPad simulator: 0 s`), then switched once to the iPhone

#### Use Case:
- **As Igor,** waiting on a whiteboard change, which runs its drawing classes on the iPad and the smoke on the iPhone
- **I want to** have the ladder run all of one device's steps, then all of the other's, starting with the one already booted
- **so that** a climb costs one boot at most, and a second climb right after costs no more than the first

#### Acceptance Criteria:
- **Scenario:** The iPad left booted by the last climb
- **Given:** the iPad simulator is booted and a branch that changes the whiteboard and the Gym Timer
- **When:** I run `just test-ladder`
- **Then:** the whiteboard's classes run first on the iPad as it is, then the iPad is shut down and the iPhone booted once for the timer's classes and the smoke, and the iPhone is left booted

---

### User Story 982:

- **Summary:** The whiteboard's ⌘V test runs on a simulator that is already up
- **Status:** not implemented. The ladder still fresh-boots the iPad when `WhiteboardPasteUITests` runs, and only then, and `test-whiteboard-ui.sh` still reboots once per suite run. The one experiment (the ⌘V test three times on one boot, 2026-11-17) failed before any key was pressed, on a tap, at load 300 on a stalled screen, so it says nothing about keys yet

#### Use Case:
- **As Igor,** running the whiteboard's paste tests again and again
- **I want to** have ⌘V and ⌘Z reach the app on a simulator that earlier runs used
- **so that** the whiteboard suite doesn't reboot the iPad on every run to get its keys through

#### Acceptance Criteria:
- **Scenario:** The keys test, twice on one boot
- **Given:** the iPad simulator booted, with the keys test already run on it
- **When:** the whiteboard suite or the ladder runs `WhiteboardPasteUITests` again
- **Then:** ⌘V pastes and ⌘Z takes it back, with no reboot in between

---

### User Story 983:

- **Summary:** A hot Mac gets its simulator shut down at the end of a run
- **Status:** implemented in f63a8e0, 1390e3d; verified on the host by the ladder's map self-test (a thermal warning from `pmset` shuts the simulator down and says why; a warning level back at 0 leaves it booted). The heat watch's own messages are not read: they live off the repo
- **Issues:** Larry's heat stop of 2026-11-17 (heavy thermal at load 84 during a ladder run)

#### Use Case:
- **As Igor,** whose Air throttles when it runs hot
- **I want to** have the ladder shut its simulator down rather than leave it booted when the Mac is hot
- **so that** a simulator left up for the next run never adds to the heat that stopped this one

#### Acceptance Criteria:
- **Scenario:** A run ends on a hot Mac
- **Given:** macOS reports a thermal or performance warning level above 0 (a level back at 0 after an earlier warning is cool; the load alone doesn't count: on this Mac it counts hung processes, and shut a cool run's simulator down at load 71 on 2026-11-17)
- **When:** the ladder's simulator rung ends, pass or fail
- **Then:** it shuts its simulator down and prints why; on a cool Mac it leaves it booted

---

### User Story 984:

- **Summary:** The wallpaper snapshots of every shut-down simulator are pruned before a boot
- **Status:** implemented in c2067b7 (through machine-doctor, which skipped every time: its `sims` command was never merged); our own prune in 9ae4b49, 0230c40; verified on the host by the ladder's map self-test (the prune runs before the boot and clears both shut-down simulators' snapshots) and on the simulator rung, 2026-11-18 (GymTimerUITests: the boot cleared the iPhone 17 and iPad snapshots, 910 MB, while both were shut down)
- **Issues:** health-04, 2026-11-17: 3.5 GB of snapshots on the iPad simulator since the morning, the disk twice under 10 GB free

#### Use Case:
- **As Igor,** whose Air's disk fills with wallpaper snapshots no one evicts
- **I want to** have them deleted on the shut-down simulators before a boot
- **so that** the boots can't push the disk under the line that stops every build, and no one has to clear it by hand

#### Acceptance Criteria:
- **Scenario:** A boot
- **Given:** the target simulator is shut down
- **When:** a run boots it
- **Then:** the wallpaper snapshots of every shut-down simulator, the target among them, are deleted first, whatever the free disk, then the simulator boots

---

### User Story 985:

- **Summary:** No more simulators booted than the Mac has build lanes (one on a 16 GB Mac)
- **Status:** implemented in f63a8e0; verified on the host by the ladder's map self-test (the iPad booted: it is shut down before the phone boots). Per lane (#954): implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh`
- **Issues:** split from story 980; #954

#### Use Case:
- **As Igor,** on a 16 GB Air where one booted simulator takes about 10 GB, or a 48 GB Mac with room for four
- **I want to** have any simulator past the Mac's lane count shut down before a run's own device boots, never one a busy lane is using
- **so that** booted simulators never starve each other, and no job loses its simulator mid-run

#### Acceptance Criteria:
- **Scenario:** Another simulator is up, on a one-lane Mac
- **Given:** a Mac with one build lane, and a different simulator booted by any earlier run
- **When:** a run needs its own device
- **Then:** the other is shut down before its device boots, so only one is ever booted

- **Scenario:** Another lane's simulator is up
- **Given:** a Mac with four build lanes and another lane's simulator booted
- **When:** a run needs its own device
- **Then:** the other lane's simulator is left booted, busy or idle, while no more than four are booted with this run's

---

### User Story 986:

- **Summary:** A simulator already booted is used as it is, with no prune and no boot
- **Status:** implemented in c2067b7; verified on the host by the ladder's map self-test (the device boots with `bootstatus -b`, which returns at once when it is up)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** running checks one after another on the same device
- **I want to** have a run that finds its simulator booted skip the snapshot prune and the boot
- **so that** a run on a booted simulator costs no extra wait

#### Acceptance Criteria:
- **Scenario:** The target is already booted
- **Given:** the target simulator is booted
- **When:** a run uses it
- **Then:** nothing is pruned and nothing boots

---

### User Story 987:

- **Summary:** The wallpaper snapshots of every shut-down simulator are pruned when a simulator run ends
- **Status:** implemented in 9ae4b49, 0230c40; verified on the host by the ladder's map self-test (the rung prunes again after its last boot) and on the simulator rung, 2026-11-18 (GymTimerUITests: the teardowns ran and found nothing more after the boot's prune; the iPhone left booted kept its own)
- **Issues:** split from story 984; Igor, 2026-11-18: "can we do that cleanup as part of test tear down since it's in sim"

#### Use Case:
- **As Igor,** whose Air's disk fills with wallpaper snapshots no one evicts
- **I want to** have them deleted on the shut-down simulators when a simulator run ends
- **so that** the snapshots a run's boots left behind are gone before the next build needs the disk

#### Acceptance Criteria:
- **Scenario:** A simulator run ends
- **Given:** the ladder's simulator rung, the whiteboard suite or the smoke is running
- **When:** it tears down, pass or fail
- **Then:** the wallpaper snapshots of every shut-down simulator are deleted; the simulator left booted keeps its own

---

### User Story 988:

- **Summary:** A booted simulator's wallpaper snapshots are never pruned
- **Status:** implemented in 9ae4b49; verified on the host by the ladder's map self-test (a booted one's snapshots stay; one booted between the look and the delete stays, and goes once it is shut down again)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** whose simulators PosterBoard holds open while they run
- **I want to** have the prune leave a booted simulator's snapshots alone, even one that booted after the prune looked
- **so that** a prune never pulls files out from under a running simulator

#### Acceptance Criteria:
- **Scenario:** A booted simulator
- **Given:** a simulator is booted, even one that booted after the prune looked
- **When:** the prune runs
- **Then:** its snapshots are left alone

---

### User Story 989:

- **Summary:** The prune says what it did in one line and never fails a boot or a run
- **Status:** implemented in 9ae4b49; verified on the host by the ladder's map self-test (one line with the simulators and the MB; one line when there is nothing; a failing `simctl` is a line and exit 0)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** reading a run's output
- **I want to** see one line naming the simulators cleared and the MB freed, and have a failed prune ignored
- **so that** housekeeping never hides a test result or stops a run

#### Acceptance Criteria:
- **Scenario:** What the prune says
- **Given:** any prune, including one whose `simctl` fails
- **When:** it finishes
- **Then:** one line names the simulators cleared and the MB freed (or says there was nothing), and it exits 0 so the boot or the run goes on

---

### User Story 1010:

- **Summary:** The smoke judges the Gym Timer's workout only once its last line has landed, and says which way a short one went
- **Status:** implemented in 20d11016; verified on the host rung (`just test`) and the simulator rung (`SMOKE_ONLY=timer just native-test-sim`, iPhone, 2026-11-19: all passed, the log read 18253 ms into the launch against the last `timer_` line, the finish's `timer_session inactive`, at 17839 ms)
- **Issues:** [#389](https://github.com/idvorkin/context-grabber/issues/389) (a workout seen ending early: 3 of 4 duck windows, no Live Activity end; the run could not say whether the workout stopped or the smoke read too soon)

#### Use Case:
- **As Igor,** reading a simulator smoke run that failed the timer's checks
- **I want to** have the smoke wait for the workout's last lines before it judges, and say how long after the last one it read the log
- **so that** a slow simulator never fails a good workout, and a failure says whether the workout stopped early or the smoke read too soon

#### Acceptance Criteria:
- **Scenario:** The smoke's timer run
- **Given:** the smoke starts its short Gym Timer workout
- **When:** the workout finishes
- **Then:** the smoke judges the log only after the finish's letting go of the audio and the Live Activity's end (or its one *unavailable* line) have been logged, waiting a bounded time for each, and prints how long after the workout's last `timer_` line it read the log
- **And:** a line that never comes is a failure naming what was missing and the last `timer_` line the workout did log, with its second into the workout, so a stopped workout reads differently from a slow one
