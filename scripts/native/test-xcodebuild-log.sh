#!/usr/bin/env bash
# xcodebuild-log.sh against a fake xcodebuild (the pipeline report of 2026-11-10): a test run gets a time limit per
# test, a build doesn't, an xcodebuild that hangs after its suite closes is stopped and judged by the log, and a run of
# built tests whose first suite never starts is stopped and fails with exit 75 (story 783), and the hang stop waits for
# the result bundle to be written in full, so a failed test's screenshots can still be opened (story 790).
set -uo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0
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
exit $fail
