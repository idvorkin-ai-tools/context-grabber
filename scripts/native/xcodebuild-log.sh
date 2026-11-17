#!/usr/bin/env bash
# Runs an xcodebuild command line, keeping its whole output in native/Build/logs/<name>.log and putting
# xcbeautify's digest on screen: the tasks with warnings or errors, and the test results. Succeeds only if the
# command exits 0 and the log carries the <done> line ("BUILD SUCCEEDED", "TEST SUCCEEDED"); a grep on exit codes
# alone would pass a failed build through a pipe. The exception is an xcodebuild that hangs after its tests finish: it
# is stopped and the log's last closing suite line decides (passed exits 0, failed exits 65). A test-without-building run
# whose first suite doesn't start in time is stopped too, and fails with exit 75 (story 783). Without xcbeautify the
# screen gets the error and result lines instead.
# Usage: xcodebuild-log.sh <name> <done> <command...>
set -uo pipefail
name=$1 done=$2
shift 2
log=${NATIVE_LOG_DIR:-native/Build/logs}/$name.log  # tests keep theirs apart
mkdir -p "${log%/*}"
if command -v xcbeautify >/dev/null; then
  show=(xcbeautify --quiet --is-ci --disable-logging)
  [ -t 1 ] || show+=(--disable-colored-output)  # piped into an agent or a log: no escape codes
else
  show=(grep -E "error:|BUILD|Test Case|TEST (SUCCEEDED|FAILED)")
fi
# xcodebuild can sit idle for good once the tests are done, holding the build lock: once a suite has closed, stop it
# after this long with no new output (a retry prints on), and let the log say how the tests went. 30 s: a good run's tail is 1–5 s, the longest seen 36 s on a
# run with failures (the timing study of 2026-11-10: the old 90 s cost 1.5 min on 10 of 27 runs).
idle=${XCODEBUILD_IDLE_SECONDS:-30}
# Story 783: with the Mac's display off or its screen locked, a run of built tests sits for a quarter of an hour or more
# before its first test (the 915 run of 2026-11-16: 17 minutes, against about 30 s lit). A healthy start, the simulator's
# boot included, is under a minute, so one with no suite started by this time is stopped and said to be. Only runs of
# built tests: a plain `test` compiles first, for as long as it takes.
start_limit=${XCODEBUILD_START_SECONDS:-180}
watch_start=0 start_watchdog=
# Every UI test gets a time limit, so a stuck case fails at 2 minutes instead of running on (one took 425 s against
# 47 s when it passes). XCTest rounds the allowance up to whole minutes; the slowest passing case takes about 61 s.
if [ "${1##*/}" = xcodebuild ]; then
  case " $* " in
    *" test "* | *" test-without-building "*)
      set -- "$@" -test-timeouts-enabled YES -default-test-execution-time-allowance 120
      # A failed case runs once more, alone, rather than the whole list again (Igor, 2026-11-10: "fix all the issues").
      # ui-timings names every case that passed only on its retry, so a flake is still seen; UI_TEST_RETRY=0 turns it off.
      [ "${UI_TEST_RETRY:-1}" = 1 ] && set -- "$@" -retry-tests-on-failure -test-iterations 2
      ;;
  esac
  case " $* " in *" test-without-building "*) watch_start=1 ;; esac
fi
stopped=$(mktemp -u) unstarted=$(mktemp -u)
stop_xcodebuild() {
  pkill -TERM -P $$ -f '/xcodebuild '
  sleep 5 || return
  pkill -KILL -P $$ -f '/xcodebuild '
}
: >"$log"
if [ "$watch_start" -eq 1 ] && [ "$start_limit" -gt 0 ]; then
  (
    waited=0
    until grep -qE "^Test Suite '[^']+' started" "$log"; do
      kill -0 $$ 2>/dev/null || exit
      if [ "$waited" -ge "$start_limit" ]; then
        pgrep -P $$ -f '/xcodebuild ' >/dev/null || exit  # it ended by itself: its own status says how
        touch "$unstarted"
        stop_xcodebuild
        exit
      fi
      sleep 1 || exit
      waited=$((waited + 1))
    done
  ) >/dev/null 2>&1 &
  start_watchdog=$!
fi
(
  until grep -qE "^Test Suite '(All|Selected) tests' (passed|failed)" "$log"; do
    kill -0 $$ 2>/dev/null || exit
    sleep 5 || exit
  done
  size=-1 quiet=0
  while [ "$quiet" -lt "$idle" ]; do
    kill -0 $$ 2>/dev/null || exit
    now=$(wc -c <"$log")
    if [ "$now" = "$size" ]; then quiet=$((quiet + 1)); else size=$now quiet=0; fi
    sleep 1 || exit
  done
  kill -0 $$ 2>/dev/null || exit
  touch "$stopped"
  stop_xcodebuild
) >/dev/null 2>&1 &
watchdog=$!
# Xcode's account tokens never reach the log or the screen.
"$@" 2>&1 | sed -u -E 's/(X-Apple-GS-Token|DSESSIONID)([:=] *)[^ ;]+/\1\2<filtered>/g' | tee "$log" | "${show[@]}"
# A wrapper may fail a build that printed its done line: BugKit's signing guard exits 78 on "No Accounts".
status=${PIPESTATUS[0]}
for w in "$watchdog" ${start_watchdog:+"$start_watchdog"}; do
  pkill -P "$w" 2>/dev/null
  kill "$w" 2>/dev/null
  wait "$w" 2>/dev/null
done
if [ -e "$unstarted" ]; then
  rm -f "$unstarted"
  # shellcheck source=scripts/native/smoke-lock.sh
  . "$(dirname "$0")/smoke-lock.sh"
  if mac_locked; then now="it is locked now"; else now="it isn't locked now, so look for a display that was asleep"; fi
  echo "no test started within $start_limit s, so xcodebuild was stopped: UI tests don't start while the Mac's display is" \
    "asleep or its screen is locked ($now); wake and unlock it, then rerun. The whole log: $log" >&2
  exit 75
fi
# Where a test run's time went, per case, on screen and as JSON lines to compare runs (ui-timings.py).
if grep -q "^Test Case '" "$log"; then
  "$(dirname "$0")/ui-timings.py" "$log" --run "$name" --jsonl "${UI_TIMINGS_JSONL:-${log%/*}/ui-timings.jsonl}" ||
    echo "ui-timings could not read $log" >&2
fi
if [ -e "$stopped" ]; then
  rm -f "$stopped"
  echo "xcodebuild hung after the tests finished, so it was stopped; the log has the result: $log" >&2
  last=$(grep -E "^Test Suite '(All|Selected) tests' (passed|failed)" "$log" | tail -1)
  case $last in *" passed"*) exit 0 ;; *) exit 65 ;; esac
fi
if [ "$status" -ne 0 ]; then
  echo "the build exited $status; the whole log: $log" >&2
  exit "$status"
fi
grep -q "$done" "$log" && exit 0
echo "no \"$done\" in the output; the whole log: $log" >&2
exit 1
