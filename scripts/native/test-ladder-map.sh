#!/usr/bin/env bash
# Host test for the ladder (story 680): runs the real scripts/native/test-ladder.sh and reads what it says. The dry runs
# check which rungs and UI test classes a change gets; the rest run it with fake just, xcodebuild, xcrun, lockf, pgrep and
# uv, so nothing builds, nothing boots and nothing takes the real lock.
set -uo pipefail
cd "$(dirname "$0")/../.."
ladder=scripts/native/test-ladder.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-ladder-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
out=$tmp/out
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; sed 's/^/     /' "$out"; fail=1; }
says() { if grep -qxF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }
never() { if grep -qF -- "$2" "$out"; then echo "     unwanted: $2"; bad "$1"; else ok "$1"; fi; }
# Fakes first on the path: pgrep so a real xcodebuild on this Mac can't change what the dry runs print.
fakes=$tmp/bin
mkdir -p "$fakes"
export MARKS=$tmp/marks
mkdir -p "$MARKS"
cat >"$fakes/pgrep" <<'F'
#!/usr/bin/env bash
case ${FAKE_BUSY:-} in
  always) echo 1; exit 0 ;;
  after-build) [ -e "$MARKS/xcodebuild" ] && { echo 1; exit 0; } ;;
esac
exit 1
F
cat >"$fakes/just" <<'F'
#!/usr/bin/env bash
echo "just $*" >>"$MARKS/just"
[ "$1" = "${FAKE_JUST_FAILS:-}" ] && exit 7
exit 0
F
cat >"$fakes/xcodebuild" <<'F'
#!/usr/bin/env bash
echo "xcodebuild $*" >>"$MARKS/xcodebuild"
if [ -n "${FAKE_XCODEBUILD_FAILS:-}" ]; then exit 65; fi
case " $* " in
  *" build-for-testing "*) echo "** TEST BUILD SUCCEEDED **" ;;
  *) echo "** TEST EXECUTE SUCCEEDED **" ;;
esac
F
cat >"$fakes/xcrun" <<'F'
#!/usr/bin/env bash
echo "xcrun $*" >>"$MARKS/xcrun"
case "$*" in
  "simctl list devices available") printf '    iPhone 17 (00000000-0000-0000-0000-000000000000) (Shutdown)\n' ;;
esac
exit 0
F
cat >"$fakes/lockf" <<'F'
#!/usr/bin/env bash
echo "lockf $3 $4" >>"$MARKS/lockf"
shift 4
exec "$@"
F
cat >"$fakes/uv" <<'F'
#!/usr/bin/env bash
exec sleep 30
F
chmod +x "$fakes"/*
dry() { PATH="$fakes:$PATH" "$ladder" --dry-run "$@" >"$out" 2>&1; }
run() {  # <env assignments...> -- <ladder arguments...>
  local vars=()
  while [ "$1" != "--" ]; do vars+=("$1"); shift; done
  shift
  rm -f "$MARKS"/*
  env PATH="$fakes:$PATH" SIM="iPhone 17" NATIVE_LOG_DIR="$tmp/logs" CHAT_PORT=18798 CHAT_BRIDGE_PORT=18797 WHITEBOARD_PORT=18799 \
    XCODEBUILD_IDLE_POLL=1 ${vars[@]+"${vars[@]}"} "$ladder" "$@" >"$out" 2>&1
}

chat_all="ChatArchiveUITests ChatImageUITests ChatNewThreadUITests ChatReactionUITests ChatSkillThreadUITests ChatVoiceUITests"
board_all="WhiteboardOnPaperUITests WhiteboardPaperGhostsUITests WhiteboardPaperPasteUITests WhiteboardPasteOnPaperUITests WhiteboardPasteUITests WhiteboardRowDeleteUITests WhiteboardTrialOnPaperUITests WhiteboardTurnOnPaperUITests WhiteboardTurnUITests"

dry --changed native/App/Chat/ChatViews.swift
says "chat code: lint names the file" "rung 0 Lint: swift-format over 1 touched Swift file(s), SwiftLint over the tree"
says "chat code: the host rung" "rung 1 Host: ContextCore's tests and the script checks"
says "chat code: the Mac build" "rung 1.5 Mac: the Catalyst build"
says "chat code: the simulator build" "rung 2 Simulator: the build with its UI tests"
says "chat code: chat's classes" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"
says "chat code: the class with no fake runs apart" "rung 2 UI tests: ChatComposeClearsUITests"
never "chat code: no whiteboard" "Whiteboard"
never "chat code: no suite without --full" "rung 2 full"

dry --changed native/App/Whiteboard/PaperBoard.swift
says "whiteboard code: its classes" "rung 2 UI tests (whiteboard, fake Cockpit, fresh boot): $board_all"
never "whiteboard code: no chat" "Chat"

dry --changed docs/TESTING.md --changed README.md
says "docs: nothing to format" "rung 0 Lint: swift-format over 0 touched Swift file(s), SwiftLint over the tree"
says "docs: no Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "docs: no simulator build" "rung 2 Simulator: skipped, nothing the simulator build compiles changed"
says "docs: no UI tests" "rung 2 UI tests: none, no app UI change"

dry --changed native/UITests/CardUITests.swift
says "a test file: its own class" "rung 2 UI tests: CardUITests"
says "a test file: the simulator builds it" "rung 2 Simulator: the build with its UI tests"
says "a test file: not in the Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"

dry --changed native/UITests/WhiteboardPaperPasteUITests.swift
says "a test file of two classes: both" "rung 2 UI tests (whiteboard, fake Cockpit, fresh boot): WhiteboardPaperPasteUITests WhiteboardPasteOnPaperUITests"

dry --changed native/UITests/WhiteboardTurnUITests.swift
says "a test class: and what inherits it" "rung 2 UI tests (whiteboard, fake Cockpit, fresh boot): WhiteboardTurnOnPaperUITests WhiteboardTurnUITests"

dry --changed native/App/Gym/GymTimerView.swift
says "unmapped code: says so" "no UI test map for: native/App/Gym/GymTimerView.swift"
says "unmapped code: names the option" "so no UI tests were chosen for them; --all runs every UI test class"
never "unmapped code: chooses nothing" "rung 2 UI tests"

dry --changed native/UITests/HomeScreen.swift
says "a shared test helper: says so" "no UI test map for: native/UITests/HomeScreen.swift"

dry --changed native/ContextCore/Tests/ContextCoreTests/StatsTests.swift
says "a host test: no Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "a host test: no simulator build" "rung 2 Simulator: skipped, nothing the simulator build compiles changed"

dry --changed native/ContextCore/Sources/ContextCore/Chat/ChatCockpit.swift
says "Mac-only code in the package: the Mac build" "rung 1.5 Mac: the Catalyst build"

dry --changed native/App/Chat/ChatViews.swift --full
says "--full: the area's suite" "rung 2 full: scripts/native/test-chat-ui.sh"
never "--full: in place of its classes" "rung 2 UI tests (chat"

dry --changed docs/TESTING.md --all
says "--all: chat" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"
says "--all: the simulator builds" "rung 2 Simulator: the build with its UI tests"

FAKE_BUSY=always dry --changed native/App/Chat/ChatViews.swift
says "dry run: says another xcodebuild would be waited for" "another xcodebuild is running now: the Mac and simulator rungs would wait for it"

# The diff itself, in a throwaway repository holding a copy of the script: committed, staged and untracked all count.
repo=$tmp/repo
mkdir -p "$repo/scripts/native"
cp -f "$ladder" "$repo/scripts/native/"
(
  cd "$repo" || exit 1
  git init -q -b main .
  git -c user.name=t -c user.email=t@example.com add .
  git -c user.name=t -c user.email=t@example.com commit -qm base
  git checkout -qb work
  mkdir -p docs native/App/Chat native/App/Whiteboard
  echo a >docs/a.md
  git add .
  git -c user.name=t -c user.email=t@example.com commit -qm words
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --base main >"$tmp/words" 2>&1
  echo b >native/App/Chat/New.swift
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --base main >"$tmp/untracked" 2>&1
)
cp -f "$tmp/words" "$out"
says "the diff, docs committed: measured from the base" "test ladder: 1 changed path(s), measured from main"
says "the diff, docs committed: no UI tests" "rung 2 UI tests: none, no app UI change"
cp -f "$tmp/untracked" "$out"
says "the diff, chat untracked: chat's classes" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"

# Climbing, with fakes.
run FAKE_JUST_FAILS=native-test-host -- --changed native/App/Chat/ChatViews.swift
status=$?
if [ "$status" -eq 7 ]; then ok "a host failure: the rung's exit"; else bad "a host failure: exit $status"; fi
says "a host failure: names the rung" "stopped on rung 1 Host (exit 7)"
if [ -e "$MARKS/lockf" ]; then bad "a host failure: nothing climbs past it"; else ok "a host failure: nothing climbs past it"; fi
if grep -qF "rung 0 Lint: ok," "$out"; then ok "a host failure: lint's seconds"; else bad "a host failure: lint's seconds"; fi

run FAKE_JUST_FAILS=native-build-mac -- --changed native/App/Chat/ChatViews.swift
says "a Mac failure: names the rung" "stopped on rung 1.5 Mac (exit 7)"
if [ -e "$MARKS/xcodebuild" ]; then bad "a Mac failure: the simulator never starts"; else ok "a Mac failure: the simulator never starts"; fi

run -- --changed docs/TESTING.md
status=$?
if [ "$status" -eq 0 ] && [ ! -e "$MARKS/lockf" ]; then ok "docs: climbs without the lane"; else bad "docs: climbs without the lane"; fi
says "docs: the Mac skipped in the seconds" "  rung 1.5 Mac: skipped"
says "docs: the end names the phone" "every rung passed; rung 3, the phone, is yours: just native-run-device"

run -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "a test file: climbs"; else bad "a test file: climbs, exit $status"; fi
if grep -qF "build.lock" "$MARKS/lockf"; then ok "the simulator rung takes the build lock"; else bad "the simulator rung takes the build lock"; fi
if head -1 "$MARKS/xcodebuild" | grep -q " build-for-testing"; then ok "the build comes first"; else bad "the build comes first"; fi
if grep -q "only-testing:GrabberNativeUITests/CardUITests test-without-building" "$MARKS/xcodebuild"; then ok "then its class alone"; else bad "then its class alone"; fi
if grep -q "simctl shutdown" "$MARKS/xcrun"; then ok "the simulator is shut down after"; else bad "the simulator is shut down after"; fi

run -- --changed native/UITests/WhiteboardPaperPasteUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "paste on paper: climbs"; else bad "paste on paper: climbs, exit $status"; fi
if grep -q "skip-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests/test1CommandVOnPaperAndCommandZ" "$MARKS/xcodebuild"; then ok "paste on paper: the keys test held back"; else bad "paste on paper: the keys test held back"; fi
if grep -q "only-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests/test1CommandVOnPaperAndCommandZ" "$MARKS/xcodebuild"; then ok "paste on paper: then on a boot of its own"; else bad "paste on paper: then on a boot of its own"; fi
if [ "$(grep -c "simctl boot " "$MARKS/xcrun")" -eq 2 ]; then ok "paste on paper: two boots"; else bad "paste on paper: two boots"; fi

run -- --changed native/App/Chat/ChatViews.swift
status=$?
if [ "$status" -eq 0 ]; then ok "chat: climbs against the fakes"; else bad "chat: climbs against the fakes, exit $status"; fi
if grep -q "GrabberNativeUITests/ChatArchiveUITests" "$MARKS/xcodebuild"; then ok "chat: runs its classes"; else bad "chat: runs its classes"; fi

run FAKE_BUSY=always XCODEBUILD_IDLE_WAIT=0 -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 75 ]; then ok "contention: the Mac or simulator rung refuses"; else bad "contention: refuses, exit $status"; fi
says "contention: says why" "another xcodebuild is running: waiting up to 0s, because a simulator run under contention counts as failed"
if [ -e "$MARKS/xcodebuild" ]; then bad "contention: nothing started"; else ok "contention: nothing started"; fi

run FAKE_BUSY=after-build FAKE_XCODEBUILD_FAILS=1 -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -ne 0 ]; then ok "a failure beside another build: fails"; else bad "a failure beside another build: fails"; fi
says "a failure beside another build: rerun, not debugged" "another xcodebuild ran during this rung: startup waits fail under contention, so this counts as failed; rerun it, don't debug it"
says "a failure beside another build: names the rung" "stopped on rung 2 Simulator (exit 65)"

exit $fail
