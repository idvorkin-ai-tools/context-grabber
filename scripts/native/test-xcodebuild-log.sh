#!/usr/bin/env bash
# xcodebuild-log.sh against a fake xcodebuild (the pipeline report of 2026-11-10): a test run gets a time limit per
# test, a build doesn't, an xcodebuild that hangs after its suite closes is stopped and judged by the log, and a run of
# built tests whose first suite never starts is stopped and fails with exit 75 (story 783), and the hang stop waits for
# the result bundle to be written in full, so a failed test's screenshots can still be opened (story 790), and a case
# that passed only on its retry fails the run unless it is quarantined with its bead (story 1017), and a failed run
# during which the Mac's screen locked exits 75, asking for a rerun unlocked, while a passed one stands (story 1018), and
# a simulator test run doesn't start on a locked screen, and one is stopped, its app ended, when the screen locks (stories 1022, 1023),
# in any of its test targets, not only the first (bead context-grabber-i5x4).
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
[ -n "${FAKE_REOPEN:-}" ] && echo "Test Suite 'Selected tests' started at now."  # a runner that restarted, opening it again
if [ -n "${FAKE_EARLY_FAIL:-}" ]; then  # a case fails while the screen is still unlocked
  c="Test Case '-[GrabberNativeUITests.SynthUITests testEarly]'"
  printf '%s\n' "$c started." "$c failed (1.000 seconds)."
fi
if [ -n "${FAKE_LOCK:-}" ]; then  # the screen locks during the run, for long enough to be seen, then unlocks
  echo '"CGSSessionScreenIsLocked"=Yes' >"$FAKE_LOCK"
  for _ in $(seq "${FAKE_LOCK_HOLD:-3}"); do sleep 1; done  # short sleeps: a stop isn't held up by a long one
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
if [ -n "${FAKE_SECOND_TARGET:-}" ]; then  # a second test target, as the contract tests run (bead i5x4)
  if [ -n "${FAKE_LOCK_BETWEEN:-}" ]; then  # the screen locks between the two targets, long enough to be seen
    echo '"CGSSessionScreenIsLocked"=Yes' >"$FAKE_LOCK_BETWEEN"
    sleep 3
    [ -n "${FAKE_UNLOCK_BETWEEN:-}" ] && echo '"CGSSessionScreenIsLocked"=No' >"$FAKE_LOCK_BETWEEN" && sleep 3
  fi
  echo "Test Suite 'All tests' started at now."
  if [ -n "${FAKE_SECOND_FAIL_LOCK:-}" ]; then  # a second-target case fails on an unlocked Mac, then the screen locks
    c="Test Case '-[GrabberNativeUITests.SecondTargetUITests testSecondFail]'"
    printf '%s\n' "$c started." "$c failed (1.000 seconds)."
    sleep 1
    echo '"CGSSessionScreenIsLocked"=Yes' >"$FAKE_SECOND_FAIL_LOCK"
  fi
  for _ in $(seq "${FAKE_SECOND_HOLD:-1}"); do sleep 1; done  # short sleeps: a stop isn't held up by a long one
  c="Test Case '-[GrabberNativeUITests.SecondTargetUITests testSecond]'"
  printf '%s\n' "$c started." "$c passed (1.000 seconds)." "Test Suite 'All tests' passed at now."
fi
if [ -n "${FAKE_LOCK_AFTER:-}" ]; then  # the screen locks once the tests are done
  echo '"CGSSessionScreenIsLocked"=Yes' >"$FAKE_LOCK_AFTER"
  sleep 3
fi
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
# Story 1022: simctl, to see which apps a lock ends on which simulator.
printf '#!/usr/bin/env bash\necho "$*" >>"%s"\n' "$dir/xcrun" >"$dir/bin/xcrun"
chmod +x "$dir/bin/xcrun"
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
# Story 1022: a simulator test run and a locked screen. The destination names a simulator and its id.
sim=(-destination "platform=iOS Simulator,id=SIM-UDID-1022")
simrun() {  # simrun [VAR=value...] -- <command...>
  local vars=()
  while [ "$1" != -- ]; do vars+=("$1"); shift; done
  shift
  rm -f "$dir/args" "$dir/xcrun"
  env ${vars[@]+"${vars[@]}"} PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
    SMOKE_LOCK_PROBE="cat $dir/lock" XCODEBUILD_LOCK_POLL=1 SIM_LOCK_POLL=1 scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" \
    "$@" 2>&1 >/dev/null
}
echo '"CGSSessionScreenIsLocked" = Yes' >"$dir/lock"
start=$SECONDS
out=$(simrun SIM_LOCK_WAIT=2 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 75 ] && ok "a simulator test run on a locked screen exits 75" || bad "a locked start exited $status: $out"
[ ! -e "$dir/args" ] && ok "and xcodebuild never started" || bad "a locked start ran xcodebuild: $(cat "$dir/args")"
[ $((SECONDS - start)) -ge 2 ] && [ $((SECONDS - start)) -lt 20 ] && ok "after waiting its 2 s for an unlock" ||
  bad "the locked start waited $((SECONDS - start)) s"
case $out in *"waiting up to 2 s"*"so the simulator test run fake didn't start"*"unlock it and rerun"*) ok "and says it waited and why";;
  *) bad "a locked start said: $out";; esac
( sleep 1; echo unlocked >"$dir/lock" ) &
out=$(simrun SIM_LOCK_WAIT=20 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 0 ] && [ -e "$dir/args" ] && ok "unlocked while it waits, the run starts and passes" || bad "an unlock in the wait: $status $out"
case $out in *"is unlocked: starting the simulator test run fake"*) ok "and says it started";; *) bad "the unlock said: $out";; esac
echo '"CGSSessionScreenIsLocked"=Yes' >"$dir/lock"
simrun SIM_LOCK_WAIT=60 -- xcodebuild -scheme X "${sim[@]}" build >/dev/null
[ $? -eq 0 ] && [ -e "$dir/args" ] && ok "a simulator build on a locked screen starts as before" || bad "a locked build was held"
simrun SIM_LOCK_WAIT=60 -- xcodebuild -scheme X test >/dev/null
[ $? -eq 0 ] && [ -e "$dir/args" ] && ok "and so does a test run that isn't on a simulator" || bad "a locked test off the simulator was held"
: >"$dir/lock"
start=$SECONDS
out=$(simrun FAKE_LOCK="$dir/lock" FAKE_LOCK_HOLD=30 FAKE_LATE_FAIL=1 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
took=$((SECONDS - start))
[ "$status" -eq 75 ] && ok "a lock during a simulator run stops it with exit 75" || bad "a lock mid-run exited $status: $out"
[ "$took" -lt 15 ] && ok "within seconds of the lock (${took} s), not when the run ends" || bad "the stop took $took s"
grep -q "testLate" "$dir/logs/fake.log" && bad "a test ran after the lock" || ok "and no test ran after it"
grep -qxF "simctl terminate SIM-UDID-1022 com.idvorkin.grabbernative" "$dir/xcrun" &&
  grep -qxF "simctl terminate SIM-UDID-1022 com.idvorkin.grabbernative.uitests.xctrunner" "$dir/xcrun" &&
  ok "and the app and its test runner are ended on that simulator" || bad "the apps ended: $(cat "$dir/xcrun" 2>/dev/null)"
case $out in *"screen locked at "*"simulator test run was stopped there"*"unlock the Mac and rerun"*) ok "and it says so";;
  *) bad "a lock mid-run said: $out";; esac
: >"$dir/lock"
out=$(simrun FAKE_LOCK="$dir/lock" FAKE_LOCK_HOLD=30 FAKE_EARLY_FAIL=1 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 65 ] && ok "stopped by a lock after a case had failed, the run fails (65)" || bad "an early failure then a lock: $status $out"
case $out in *"1 case(s) had already failed before that"*) ok "and says a case failed first";; *) bad "an early failure then a lock said: $out";; esac
: >"$dir/lock"
out=$(simrun FAKE_LOCK_AFTER="$dir/lock" -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 0 ] && ok "a lock once the tests are done doesn't stop the run, and its pass stands" || bad "a lock after the tests: $status $out"
[ ! -s "$dir/xcrun" ] && ok "and ends no app" || bad "a lock after the tests ended apps: $(cat "$dir/xcrun")"
# Bead context-grabber-i5x4: a run of two test targets closes a suite after each; the stop stays on to the last.
: >"$dir/lock"
start=$SECONDS
out=$(simrun FAKE_SECOND_TARGET=1 FAKE_LOCK_BETWEEN="$dir/lock" FAKE_SECOND_HOLD=30 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
took=$((SECONDS - start))
[ "$status" -eq 75 ] && ok "a lock between two test targets stops the run once the second starts (75)" ||
  bad "a lock between targets exited $status: $out"
[ "$took" -lt 20 ] && ok "within seconds (${took} s), not when the second target ends" || bad "the stop between targets took $took s"
grep -q "testSecond" "$dir/logs/fake.log" && bad "the second target's test ran on a locked Mac" || ok "and its test never ran"
grep -qxF "simctl terminate SIM-UDID-1022 com.idvorkin.grabbernative" "$dir/xcrun" && ok "and the app is ended" ||
  bad "a stop between targets ended: $(cat "$dir/xcrun" 2>/dev/null)"
: >"$dir/lock"
out=$(simrun FAKE_SECOND_TARGET=1 FAKE_LOCK_BETWEEN="$dir/lock" FAKE_UNLOCK_BETWEEN=1 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 0 ] && grep -q "testSecond.*passed" "$dir/logs/fake.log" &&
  ok "unlocked again before the second target starts, the run goes on and passes" || bad "a lock lifted between targets: $status $out"
case $out in *"screen locked during the run"*"passed anyway"*) ok "and says the screen locked";; *) bad "a lifted lock said: $out";; esac
: >"$dir/lock"
out=$(simrun FAKE_SECOND_TARGET=1 FAKE_LOCK_BETWEEN="$dir/lock" FAKE_UNLOCK_BETWEEN=1 FAKE_SECOND_FAIL_LOCK="$dir/lock" \
  FAKE_SECOND_HOLD=30 -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 65 ] && ok "a lock lifted between targets, then a failure, then a lock that stops the run: it fails (65)" ||
  bad "a failure after a lifted lock, then a lock: $status $out"
case $out in *"1 case(s) had already failed before that"*) ok "and says a case failed first";;
  *) bad "a failure after a lifted lock, then a lock, said: $out";; esac
: >"$dir/lock"
out=$(simrun FAKE_SECOND_TARGET=1 FAKE_LOCK_AFTER="$dir/lock" -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 0 ] && [ ! -s "$dir/xcrun" ] && ok "a lock after the last of two targets doesn't stop the run" ||
  bad "a lock after the second target: $status $out"
: >"$dir/lock"
out=$(simrun FAKE_REOPEN=1 FAKE_LOCK_AFTER="$dir/lock" -- xcodebuild -scheme X "${sim[@]}" test-without-building)
status=$?
[ "$status" -eq 0 ] && [ ! -s "$dir/xcrun" ] && ok "a suite opened twice and closed once is finished: a lock after it stands" ||
  bad "a lock after a reopened suite: $status $out"
exit $fail
