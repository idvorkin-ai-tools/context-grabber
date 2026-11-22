#!/usr/bin/env bash
# xcodebuild-log.sh against a fake xcodebuild (the pipeline report of 2026-11-10): a test run gets a time limit per
# test, a build doesn't, an xcodebuild that hangs after its suite closes is stopped and judged by the log, and a run of
# built tests whose first suite never starts is stopped and fails with exit 75 (story 783), and the hang stop waits for
# the result bundle to be written in full, so a failed test's screenshots can still be opened (story 790), and a case
# that passed only on its retry fails the run unless it is quarantined with its bead (story 1017), and a failed run
# during which the Mac's screen locked exits 75, asking for a rerun unlocked, while a passed one stands (story 1018).
set -uo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0
# Story 1018: the wrapper watches the Mac's screen during a test run. Unlocked, unless a case below locks it: this check
# runs on whatever Mac runs it, locked or not.
export SMOKE_LOCK_PROBE="echo unlocked"
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
mkdir -p "$dir/bin"
cat >"$dir/bin/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >"$FAKE_ARGS"
[ -n "${FAKE_SLOW:-}" ] && sleep "$FAKE_SLOW"  # a compile, or a start that takes this long
if [ -n "${FAKE_NO_START:-}" ]; then  # a dark or locked Mac: the runner waits, and no test starts
  while :; do sleep 1; done
fi
echo "Test Suite 'Selected tests' started at now."
if [ -n "${FAKE_EARLY_FAIL:-}" ]; then  # a case fails while the screen is still unlocked
  c="Test Case '-[GrabberNativeUITests.SynthUITests testEarly]'"
  printf '%s\n' "$c started." "$c failed (1.000 seconds)."
fi
if [ -n "${FAKE_LOCK:-}" ]; then  # the screen locks during the run, for long enough to be seen, then unlocks
  echo '"CGSSessionScreenIsLocked"=Yes' >"$FAKE_LOCK"
  sleep 3
  echo '"CGSSessionScreenIsLocked"=No' >"$FAKE_LOCK"
fi
if [ -n "${FAKE_LATE_FAIL:-}" ]; then  # a case fails after the lock
  c="Test Case '-[GrabberNativeUITests.SynthUITests testLate]'"
  printf '%s\n' "$c started." "$c failed (1.000 seconds)."
fi
if [ -n "${FAKE_FLAKY:-}" ]; then  # Class.test: fails, then passes on its retry
  c="Test Case '-[GrabberNativeUITests.${FAKE_FLAKY%.*} ${FAKE_FLAKY#*.}]'"
  printf '%s\n' "$c started." "$c failed (1.000 seconds)." "$c started." "$c passed (1.000 seconds)."
fi
echo "Test Suite 'Selected tests' ${FAKE_RESULT:-passed} at now."
bundle= prev=
for a in "$@"; do [ "$prev" = -resultBundlePath ] && bundle=$a; prev=$a; done
if [ -n "$bundle" ]; then  # like xcodebuild: Staging while it writes, quietly, then Info.plist, and Staging goes
  mkdir -p "$bundle/Staging" "$bundle/Data"
  for _ in $(seq "${FAKE_BUNDLE_SECONDS:-0}"); do sleep 1; done  # short sleeps: a stop isn't held up by a long one
  echo "<plist/>" >"$bundle/Info.plist"
  rm -rf "$bundle/Staging"
fi
if [ -n "${FAKE_RETRY:-}" ]; then  # the retry runs on, printing, well past the idle limit, then passes
  for _ in $(seq 16); do echo "    t = 0.00s Retrying"; sleep 0.5; done
  echo "Test Suite 'Selected tests' passed at now."
fi
[ -n "${FAKE_EXIT:-}" ] && exit "$FAKE_EXIT"  # a failed run that ends by itself, as xcodebuild's does
[ -n "${FAKE_HANG:-}" ] && while :; do sleep 1; done  # stays this script, so the watchdog sees "/xcodebuild "
echo "** TEST SUCCEEDED **"
FAKE
chmod +x "$dir/bin/xcodebuild"
run() { PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
  scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" "$@" >/dev/null 2>&1; }

run xcodebuild -scheme X test-without-building
args=$(cat "$dir/args")
case " $args " in *" -test-timeouts-enabled YES -default-test-execution-time-allowance 120 "*) ok "a test run gets a 2-minute limit per test";; *) bad "no time limit on a test run: $args";; esac
case " $args " in *" -retry-tests-on-failure -test-iterations 2 "*) ok "and a failed case is retried once, alone";; *) bad "no retry on a test run: $args";; esac
UI_TEST_RETRY=0 run xcodebuild -scheme X test
case " $(cat "$dir/args") " in *"-retry-tests-on-failure"*) bad "UI_TEST_RETRY=0 still retried";; *) ok "UI_TEST_RETRY=0 turns the retry off";; esac
run xcodebuild -scheme X build
case " $(cat "$dir/args") " in *"-test-timeouts-enabled"*) bad "a build got a test time limit";; *) ok "a build gets none";; esac

start=$SECONDS
FAKE_HANG=1 XCODEBUILD_IDLE_SECONDS=1 run xcodebuild -scheme X test
status=$?
[ $((SECONDS - start)) -lt 30 ] && ok "a hang after a passing suite is stopped" || bad "the hang wasn't stopped"
[ "$status" -eq 0 ] && ok "and the log's passed decides" || bad "a passed suite that hung exited $status"
FAKE_HANG=1 FAKE_RESULT=failed XCODEBUILD_IDLE_SECONDS=1 run xcodebuild -scheme X test
[ $? -eq 65 ] && ok "a failed suite that hung exits 65" || bad "a failed suite that hung didn't exit 65"
FAKE_HANG=1 FAKE_RESULT=failed FAKE_RETRY=1 XCODEBUILD_IDLE_SECONDS=1 run xcodebuild -scheme X test
status=$?
[ "$status" -eq 0 ] && ok "a retry still printing isn't stopped, and its passed decides" || bad "a retry that passed exited $status"

# Story 1017: a case that passed only on its retry fails a run xcodebuild calls a success, unless it is quarantined.
flake() { FAKE_FLAKY=SynthUITests.testFlaky PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" \
  UI_TIMINGS_JSONL="$dir/t.jsonl" UI_QUARANTINE="$dir/quarantine" "$@" scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" \
  xcodebuild -scheme X test 2>&1 >/dev/null; }
: >"$dir/quarantine"
out=$(flake env)
status=$?
[ "$status" -eq 65 ] && ok "a case that passed only on its retry fails the run" || bad "a retried-only pass exited $status"
case $out in *"passed only on its retry, so the run fails"*"SynthUITests.testFlaky"*) ok "and the failure names it";;
  *) bad "a retried-only pass said: $out";; esac
out=$(flake env FAKE_HANG=1 XCODEBUILD_IDLE_SECONDS=1)
[ $? -eq 65 ] && ok "and so it does after a hang that is stopped" || bad "a retried-only pass after a hang: $out"
echo "SynthUITests.testFlaky because it is flaky" >"$dir/quarantine"
flake env >/dev/null
[ $? -eq 65 ] && ok "a quarantine without the bead that tracks it quarantines nothing" || bad "an untracked quarantine let it pass"
echo "SynthUITests.testFlaky context-grabber-test1 the race is being chased" >"$dir/quarantine"
out=$(flake env)
[ $? -eq 0 ] && ok "a quarantined case's retried pass doesn't fail the run" || bad "a quarantined flake failed the run: $out"
echo "SynthUITests #1 the whole class" >"$dir/quarantine"
flake env >/dev/null
[ $? -eq 0 ] && ok "nor does one in a quarantined class" || bad "a flake in a quarantined class failed the run"

# Story 790: the hang stop waits for the result bundle. The fake writes it for 8 s after the suite closes, printing
# nothing, then hangs: stopping at the 1 s idle limit (the suite line is looked for every 5 s) would leave Staging and no Info.plist.
mkdir -p "$dir/logs/fake.xcresult/Staging"  # last run's bundle: replaced, as xcodebuild refuses a path that exists
start=$SECONDS
out=$(FAKE_HANG=1 FAKE_RESULT=failed FAKE_BUNDLE_SECONDS=8 XCODEBUILD_IDLE_SECONDS=1 PATH="$dir/bin:$PATH" \
  NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
  scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" xcodebuild -scheme X test 2>&1 >/dev/null)
status=$?
took=$((SECONDS - start))
case " $(cat "$dir/args") " in *" -resultBundlePath $dir/logs/fake.xcresult "*) ok "a test run's bundle is named for the run, beside its log";;
  *) bad "no bundle path on a test run: $(cat "$dir/args")";; esac
[ -e "$dir/logs/fake.xcresult/Info.plist" ] && [ ! -e "$dir/logs/fake.xcresult/Staging" ] &&
  ok "a hang is stopped only once the bundle is written in full" || bad "the bundle was cut off: $(ls "$dir/logs/fake.xcresult")"
[ "$took" -ge 8 ] && [ "$took" -lt 30 ] && ok "and it waited for it, not forever (${took} s)" || bad "the bundle wait took $took s"
[ "$status" -eq 65 ] && ok "and the log's failed still decides" || bad "a failed suite whose bundle was waited for exited $status"
case $out in *"the failed tests' screenshots: $dir/logs/fake.xcresult"*) ok "and the failure names the bundle";;
  *) bad "the failure said: $out";; esac
start=$SECONDS
out=$(FAKE_HANG=1 FAKE_BUNDLE_SECONDS=600 XCODEBUILD_IDLE_SECONDS=1 XCODEBUILD_BUNDLE_SECONDS=2 PATH="$dir/bin:$PATH" \
  NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
  scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" xcodebuild -scheme X test 2>&1 >/dev/null)
status=$?
[ $((SECONDS - start)) -lt 30 ] && ok "a bundle that's never written in full is given up on" || bad "the bundle wait didn't end"
[ "$status" -eq 0 ] && ok "and the log's passed decides" || bad "a passed suite with an unwritten bundle exited $status"
case $out in *"wasn't written in full 2 s after the tests finished"*) ok "and it says the bundle can't be opened";;
  *) bad "an unwritten bundle said: $out";; esac
run xcodebuild -scheme X test -resultBundlePath "$dir/mine.xcresult"
case " $(cat "$dir/args") " in *"-resultBundlePath $dir/mine.xcresult "*"-resultBundlePath"*) bad "a named bundle got a second path";;
  *" -resultBundlePath $dir/mine.xcresult "*) ok "a command that names its bundle keeps it";; *) bad "the named bundle was lost";; esac
[ -e "$dir/mine.xcresult/Info.plist" ] && ok "and that bundle is the one waited on" || bad "the named bundle wasn't written"
run xcodebuild -scheme X build
case " $(cat "$dir/args") " in *"-resultBundlePath"*) bad "a build got a result bundle path";; *) ok "a build gets no bundle path";; esac

# Story 783: a run of built tests that never starts its first suite.
start=$SECONDS
out=$(FAKE_NO_START=1 XCODEBUILD_START_SECONDS=1 SMOKE_LOCK_PROBE="echo unlocked" PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" \
  FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" \
  xcodebuild -scheme X test-without-building 2>&1 >/dev/null)
status=$?
[ $((SECONDS - start)) -lt 30 ] && ok "a run whose first test never starts is stopped" || bad "an unstarted run wasn't stopped"
[ "$status" -eq 75 ] && ok "and exits 75, could not start" || bad "an unstarted run exited $status"
case $out in *"no test started within 1 s"*"display is asleep or its screen is locked"*) ok "and names the dark or locked screen";;
  *) bad "an unstarted run said: $out";; esac
FAKE_SLOW=2 XCODEBUILD_START_SECONDS=1 run xcodebuild -scheme X test
[ $? -eq 0 ] && ok "a test run that compiles first isn't watched for its start" || bad "a slow test-and-build run was stopped"
FAKE_SLOW=2 XCODEBUILD_START_SECONDS=1 run xcodebuild -scheme X build
[ $? -eq 0 ] && ok "nor is a build" || bad "a slow build was stopped"
FAKE_SLOW=2 XCODEBUILD_START_SECONDS=5 run xcodebuild -scheme X test-without-building
[ $? -eq 0 ] && ok "a run that starts inside the limit runs on" || bad "a run that started in time was stopped"
# Story 1018: the screen locks for a while during the run.
locked() { : >"$dir/lock"; FAKE_LOCK="$dir/lock" SMOKE_LOCK_PROBE="cat $dir/lock" XCODEBUILD_LOCK_POLL=1 PATH="$dir/bin:$PATH" \
  NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" "$@" \
  scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" xcodebuild -scheme X test 2>&1 >/dev/null; }
out=$(locked env FAKE_LATE_FAIL=1 FAKE_RESULT=failed FAKE_HANG=1 XCODEBUILD_IDLE_SECONDS=1)
status=$?
[ "$status" -eq 75 ] && ok "a failed run during which the screen locked exits 75, not run" || bad "a failed locked run exited $status: $out"
case $out in *"screen locked during the run (first seen locked at "*"a test failed after that"*"unlock the Mac and rerun"*) ok "and says the screen locked and to rerun";;
  *) bad "a failed locked run said: $out";; esac
out=$(locked env FAKE_LATE_FAIL=1 FAKE_RESULT=failed FAKE_EXIT=65)
[ $? -eq 75 ] && ok "and so does one whose xcodebuild exits by itself" || bad "a failed locked run that ended itself: $out"
out=$(locked env FAKE_RESULT=failed FAKE_EXIT=65)
status=$?
[ "$status" -eq 65 ] && ok "a locked run that failed with no failed test (a build) fails as before" || bad "a locked build failure exited $status: $out"
case $out in *"wasn't a test, so it counts as a failure"*) ok "and names the lock";; *) bad "a locked build failure said: $out";; esac
out=$(locked env FAKE_EARLY_FAIL=1 FAKE_LATE_FAIL=1 FAKE_RESULT=failed FAKE_EXIT=65)
status=$?
[ "$status" -eq 65 ] && ok "a case that failed before the screen locked fails the run as before" || bad "an early failure exited $status: $out"
out=$(locked env FAKE_FLAKY=SynthUITests.testFlaky UI_QUARANTINE="$dir/none")
[ $? -eq 75 ] && ok "and one that passed a case only on its retry" || bad "a locked retried-only pass: $out"
out=$(locked env)
status=$?
[ "$status" -eq 0 ] && ok "a passed run during which the screen locked stands" || bad "a passed locked run exited $status: $out"
case $out in *"screen locked during the run"*"it passed anyway"*) ok "and says the screen locked";;
  *) bad "a passed locked run said: $out";; esac
out=$(FAKE_RESULT=failed FAKE_EXIT=65 PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
  XCODEBUILD_LOCK_POLL=1 scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" xcodebuild -scheme X test 2>&1 >/dev/null)
status=$?
[ "$status" -ne 75 ] && [ "$status" -ne 0 ] && ok "a failed run with the screen never locked fails as before ($status)" ||
  bad "a failed unlocked run exited $status"
case $out in *"screen locked"*) bad "an unlocked run blamed the lock: $out";; *) ok "and doesn't blame the lock";; esac
exit $fail
