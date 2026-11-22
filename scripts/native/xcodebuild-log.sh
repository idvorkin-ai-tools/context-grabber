#!/usr/bin/env bash
# Runs an xcodebuild command line, keeping its whole output in native/Build/logs/<name>.log and putting
# xcbeautify's digest on screen: the tasks with warnings or errors, and the test results. Succeeds only if the
# command exits 0 and the log carries the <done> line ("BUILD SUCCEEDED", "TEST SUCCEEDED"); a grep on exit codes
# alone would pass a failed build through a pipe. The exception is an xcodebuild that hangs after its tests finish: it
# is stopped and the log's last closing suite line decides (passed exits 0, failed exits 65). A test-without-building run
# whose first suite doesn't start in time is stopped too, and fails with exit 75 (story 783). Without xcbeautify the
# screen gets the error and result lines instead. A test run's result bundle, with the screenshots its failed tests
# kept, is native/Build/logs/<name>.xcresult unless the command names its own (story 790). A test run that would pass
# fails with exit 65 when a case passed only on its retry, unless scripts/native/ui-quarantine.txt names it (story 1017).
# A test run that fails after the Mac's screen was seen locked during it exits 75, asking for a rerun unlocked (story 1018).
# A test run on a simulator doesn't start while the screen is locked (it waits up to 2 minutes, then exits 75), and one
# whose tests are still running when the screen locks is stopped, the app ended on the simulator, and exits 75 (stories 1022, 1023).
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
# after this long with no new output, and let the log say how the tests went. 10 s: a good run's tail is 1–5 s. The
# closing suite line comes once, after every retry (retries run inline, before it), so stopping early can't cut a test
# short: it only skips xcodebuild's idle tail (36 s seen on a run with failures; the 915 run of 2026-11-16 hung 38 s).
# The old 90 s cost 1.5 min on 10 of 27 runs (the timing study of 2026-11-10), 30 s up to 20 s more (story 689).
idle=${XCODEBUILD_IDLE_SECONDS:-10}
# Story 783: with the Mac's display off or its screen locked, a run of built tests sits for a quarter of an hour or more
# before its first test (the 915 run of 2026-11-16: 17 minutes, against about 30 s lit). A healthy start, the simulator's
# boot included, is under a minute, so one with no suite started by this time is stopped and said to be. Only runs of
# built tests: a plain `test` compiles first, for as long as it takes.
start_limit=${XCODEBUILD_START_SECONDS:-180}
# Story 1018 (bead context-grabber-2v63): a locked Mac starves the simulator's audio, and opening the mic can then
# abort the app inside Apple's audio toolbox. The screen is looked at this often during a test run; a lock of a few
# seconds is enough to do it, so a check only at the start or the end would miss it.
lock_poll=${XCODEBUILD_LOCK_POLL:-2}
# shellcheck source=scripts/native/smoke-lock.sh
. "$(dirname "$0")/smoke-lock.sh"
watch_start=0 start_watchdog= lock_watch= is_test=0 bundle=
# Story 790: after its last suite closes, xcodebuild writes the result bundle, quietly: about 5 s on a good run, 30 s or
# more with failures and their screenshots. Stopped before it finishes, the bundle can't be opened (no Info.plist, only
# Staging) and the screenshots are lost, so the hang stop waits for it, up to this long after the suite closed.
bundle_limit=${XCODEBUILD_BUNDLE_SECONDS:-120}
# Every UI test gets a time limit, so a stuck case fails at 2 minutes instead of running on (one took 425 s against
# 47 s when it passes). XCTest rounds the allowance up to whole minutes; the slowest passing case takes about 61 s.
if [ "${1##*/}" = xcodebuild ]; then
  case " $* " in
    *" test "* | *" test-without-building "*)
      set -- "$@" -test-timeouts-enabled YES -default-test-execution-time-allowance 120
      # A failed case runs once more, alone, rather than the whole list again (Igor, 2026-11-10: "fix all the issues").
      # The retry finishes the run and catches the flake; a case that passed only on it fails the run below (story 1017).
      # UI_TEST_RETRY=0 turns it off.
      [ "${UI_TEST_RETRY:-1}" = 1 ] && set -- "$@" -retry-tests-on-failure -test-iterations 2
      ;;
  esac
  case " $* " in *" test-without-building "*) watch_start=1 ;; esac
  case " $* " in
    *" test "* | *" test-without-building "*)
      is_test=1
      # Story 790: the bundle at a known path, so the hang stop below can wait for xcodebuild to finish writing it. It
      # takes this run's name; the last run of that name replaces it, so bundles don't pile up.
      prev=
      for a in "$@"; do
        [ "$prev" = -resultBundlePath ] && bundle=$a
        prev=$a
      done
      if [ -z "$bundle" ]; then
        bundle=${log%.log}.xcresult
        rm -rf "$bundle"  # xcodebuild refuses a path that exists
        set -- "$@" -resultBundlePath "$bundle"
      fi
      ;;
  esac
fi
# Story 1022 (bead context-grabber-208e): a test run on a simulator, and the simulator's id from its destination.
sim_test=0 sim_udid=
if [ "$is_test" -eq 1 ]; then
  prev=
  for a in "$@"; do
    if [ "$prev" = -destination ]; then
      case $a in *"iOS Simulator"*) sim_test=1 sim_udid=$(sed -nE 's/^(.*,)?id=([^,]+).*$/\2/p' <<<"$a") ;; esac
    fi
    prev=$a
  done
fi
# The app and its UI test runner, ended on the simulator when a lock stops the run, before a test can open the mic.
sim_apps=${SIM_TEST_BUNDLES:-com.idvorkin.grabbernative com.idvorkin.grabbernative.uitests.xctrunner}
end_sim_apps() {
  [ -n "$sim_udid" ] || return 0
  for b in $sim_apps; do xcrun simctl terminate "$sim_udid" "$b" >/dev/null 2>&1; done
  return 0
}
# A locked Mac starves the simulator's audio server, and opening the mic then aborts the app about ten seconds on, a
# crash dialog on the Mac each time: so a locked screen doesn't start a simulator test run.
if [ "$sim_test" -eq 1 ]; then
  wait_unlocked "the simulator test run $name" || exit 75
fi
stopped=$(mktemp -u) unstarted=$(mktemp -u) unfinished=$(mktemp -u) locked_at=$(mktemp -u) lock_stopped=$(mktemp -u)
# Written in full: xcodebuild writes Info.plist and drops Staging last. No bundle to wait for (a build) counts as written.
bundle_written() { [ -z "$bundle" ] || { [ -e "$bundle/Info.plist" ] && [ ! -e "$bundle/Staging" ]; }; }
stop_xcodebuild() {
  pkill -TERM -P $$ -f '/xcodebuild '
  sleep 5 || return
  pkill -KILL -P $$ -f '/xcodebuild '
}
# Story 1022: at once, not after stop_xcodebuild's 5 s: the app is ended with xcodebuild, and again after, in case a
# retry had launched it again meanwhile.
stop_for_lock() {
  pkill -TERM -P $$ -f '/xcodebuild '
  end_sim_apps
  sleep 2
  pkill -KILL -P $$ -f '/xcodebuild '
  end_sim_apps
}
# Story 1023 (bead context-grabber-i5x4): the tests are running until a closing suite line, and again whenever a target's
# suite starts after the last one closed: a run of several test targets (the contract tests are two) opens and closes
# its top suite once per target. Before the first suite starts, the app is being installed and launched: running too.
# The last top suite line decides, not a count: a runner that restarts may open a suite twice and close it once.
tests_running() {
  case $(grep -E "^Test Suite '(All|Selected) tests' (started|passed|failed)" "$log" | tail -1) in
    *" passed"* | *" failed"*) return 1 ;;
  esac
  return 0
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
  size=-1 quiet=0 waited=0
  until [ "$quiet" -ge "$idle" ] && { bundle_written || [ "$waited" -ge "$bundle_limit" ]; }; do
    kill -0 $$ 2>/dev/null || exit
    now=$(wc -c <"$log")
    if [ "$now" = "$size" ]; then quiet=$((quiet + 1)); else size=$now quiet=0; fi
    sleep 1 || exit
    waited=$((waited + 1))
  done
  kill -0 $$ 2>/dev/null || exit
  bundle_written || touch "$unfinished"
  touch "$stopped"
  stop_xcodebuild
) >/dev/null 2>&1 &
watchdog=$!
if [ "$is_test" -eq 1 ]; then
  (
    while kill -0 $$ 2>/dev/null; do
      if mac_locked; then
        # When it was first seen locked, and how many cases had failed by then: those failed on an unlocked Mac.
        [ -e "$locked_at" ] || echo "$(date "+%H:%M:%S") $(grep -cE "^Test Case '.+' failed" "$log")" >"$locked_at"
        # Story 1022: on a simulator, a run whose tests are still running stops here. Once the last suite has closed,
        # no test can open the mic any more, and the result stands (story 1018 reads it). It keeps looking after a
        # closing line: a run of several test targets closes one per target, and the next can start (bead i5x4).
        if [ "$sim_test" -eq 1 ] && tests_running; then
          touch "$lock_stopped"
          stop_for_lock
          exit
        fi
      fi
      sleep "$lock_poll" || exit
    done
  ) >/dev/null 2>&1 &
  lock_watch=$!
fi
# Xcode's account tokens never reach the log or the screen.
"$@" 2>&1 | sed -u -E 's/(X-Apple-GS-Token|DSESSIONID)([:=] *)[^ ;]+/\1\2<filtered>/g' | tee "$log" | "${show[@]}"
# A wrapper may fail a build that printed its done line: BugKit's signing guard exits 78 on "No Accounts".
status=${PIPESTATUS[0]}
for w in "$watchdog" ${start_watchdog:+"$start_watchdog"} ${lock_watch:+"$lock_watch"}; do
  pkill -P "$w" 2>/dev/null
  kill "$w" 2>/dev/null
  wait "$w" 2>/dev/null
done
if [ -e "$lock_stopped" ]; then
  rm -f "$lock_stopped"
  end_sim_apps  # the watcher may have been ended before its second go
  read -r at before <"$locked_at"
  rm -f "$locked_at" "$unstarted"
  if [ "${before:-0}" -gt 0 ]; then
    echo "the Mac's screen locked at $at, so the simulator test run was stopped there, but $before case(s) had already" \
      "failed before that, so it counts as a failure; the whole log: $log" >&2
    exit 65
  fi
  echo "the Mac's screen locked at $at, so the simulator test run was stopped there and the app ended on the simulator," \
    "before a test could open the mic: a locked Mac starves the simulator's audio and the app can crash (story 1023)." \
    "Not run, not failed; unlock the Mac and rerun. The whole log: $log" >&2
  exit 75
fi
if [ -e "$unstarted" ]; then
  rm -f "$unstarted" "$locked_at"
  if mac_locked; then now="it is locked now"; else now="it isn't locked now, so look for a display that was asleep"; fi
  echo "no test started within $start_limit s, so xcodebuild was stopped: UI tests don't start while the Mac's display is" \
    "asleep or its screen is locked ($now); wake and unlock it, then rerun. The whole log: $log" >&2
  exit 75
fi
# Where a test run's time went, per case, on screen and as JSON lines to compare runs (ui-timings.py), and the cases that
# passed only on their retry and aren't quarantined (story 1017).
flaky=$(mktemp "${TMPDIR:-/tmp}/ui-flaky.XXXXXX")
trap 'rm -f "$flaky" "$locked_at"' EXIT
# Story 1018: a test that failed after the screen was seen locked isn't a test's failure: the run could not run as it
# should. Only when every failed case failed after the lock was first seen; a build that failed, or a case that failed
# while the screen was still unlocked, fails as before, with the lock named.
locked_failure() {
  [ -s "$locked_at" ] || return 0
  local at before failed
  read -r at before <"$locked_at"
  failed=$(grep -cE "^Test Case '.+' failed" "$log")
  if [ "$failed" -eq 0 ] || [ "${before:-0}" -gt 0 ]; then
    echo "the Mac's screen locked during the run (first seen locked at $at), but what failed failed before that or" \
      "wasn't a test, so it counts as a failure" >&2
    return 0
  fi
  [ -n "$bundle" ] && bundle_written && echo "the failed tests' screenshots: $bundle" >&2
  echo "the Mac's screen locked during the run (first seen locked at $at), and a test failed after that: a locked Mac" \
    "starves the simulator's audio and stalls UI tests (opening the mic can crash the app), so this run counts as not" \
    "run, not failed; unlock the Mac and rerun. The whole log: $log" >&2
  exit 75
}
if grep -q "^Test Case '" "$log"; then
  "$(dirname "$0")/ui-timings.py" "$log" --run "$name" --jsonl "${UI_TIMINGS_JSONL:-${log%/*}/ui-timings.jsonl}" \
    --flaky-out "$flaky" || echo "ui-timings could not read $log" >&2
fi
# Story 1017: a run that would pass, with a case that passed only on its retry, fails: a flake is a failure to fix, not a
# pass to forget. A known one, chased under its bead, goes in the quarantine file instead.
pass() {
  if [ -s "$flaky" ]; then
    locked_failure
    echo "passed only on its retry, so the run fails (a flake: fix the race, or quarantine it with its bead in" \
      "scripts/native/ui-quarantine.txt): $(paste -sd' ' "$flaky"); the whole log: $log" >&2
    [ -n "$bundle" ] && bundle_written && echo "the failed tries' screenshots: $bundle" >&2
    exit 65
  fi
  [ -s "$locked_at" ] && echo "the Mac's screen locked during the run (first seen locked at $(cut -d' ' -f1 "$locked_at")); it passed anyway" >&2
  exit 0
}
if [ -e "$stopped" ]; then
  rm -f "$stopped"
  echo "xcodebuild hung after the tests finished, so it was stopped; the log has the result: $log" >&2
  if [ -e "$unfinished" ]; then
    rm -f "$unfinished"
    echo "its result bundle wasn't written in full $bundle_limit s after the tests finished, so it can't be opened: $bundle" >&2
  fi
  last=$(grep -E "^Test Suite '(All|Selected) tests' (passed|failed)" "$log" | tail -1)
  case $last in
    *" passed"*) pass ;;
    *)
      locked_failure
      [ -n "$bundle" ] && bundle_written && echo "the failed tests' screenshots: $bundle" >&2
      exit 65
      ;;
  esac
fi
if [ "$status" -ne 0 ]; then
  locked_failure
  [ -n "$bundle" ] && bundle_written && echo "the failed tests' screenshots: $bundle" >&2
  echo "the build exited $status; the whole log: $log" >&2
  exit "$status"
fi
grep -q "$done" "$log" && pass
locked_failure
echo "no \"$done\" in the output; the whole log: $log" >&2
exit 1
