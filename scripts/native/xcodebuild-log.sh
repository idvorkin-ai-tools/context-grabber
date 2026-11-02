#!/usr/bin/env bash
# Runs an xcodebuild command line, keeping its whole output in native/Build/logs/<name>.log and putting
# xcbeautify's digest on screen: the tasks with warnings or errors, and the test results. Succeeds only if the
# command exits 0 and the log carries the <done> line ("BUILD SUCCEEDED", "TEST SUCCEEDED"); a grep on exit codes
# alone would pass a failed build through a pipe. The exception is an xcodebuild that hangs after its tests finish: it
# is stopped and the log's closing suite line decides (passed exits 0, failed exits 65). Without xcbeautify the screen
# gets the error and result lines instead.
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
# xcodebuild can sit idle for good once the tests are done, holding the build lock: stop it a while after the last
# suite closes, and let the log say how the tests went.
idle=${XCODEBUILD_IDLE_SECONDS:-90}
stopped=$(mktemp -u)
: >"$log"
(
  until grep -qE "^Test Suite '(All|Selected) tests' (passed|failed)" "$log"; do
    kill -0 $$ 2>/dev/null || exit
    sleep 5 || exit
  done
  sleep "$idle" || exit
  kill -0 $$ 2>/dev/null || exit
  touch "$stopped"
  pkill -TERM -P $$ -f '/xcodebuild '
  sleep 5 || exit
  pkill -KILL -P $$ -f '/xcodebuild '
) >/dev/null 2>&1 &
watchdog=$!
# Xcode's account tokens never reach the log or the screen.
"$@" 2>&1 | sed -u -E 's/(X-Apple-GS-Token|DSESSIONID)([:=] *)[^ ;]+/\1\2<filtered>/g' | tee "$log" | "${show[@]}"
# A wrapper may fail a build that printed its done line: BugKit's signing guard exits 78 on "No Accounts".
status=${PIPESTATUS[0]}
pkill -P "$watchdog" 2>/dev/null
kill "$watchdog" 2>/dev/null
wait "$watchdog" 2>/dev/null
if [ -e "$stopped" ]; then
  rm -f "$stopped"
  echo "xcodebuild hung after the tests finished, so it was stopped; the log has the result: $log" >&2
  if grep -qE "^Test Suite '(All|Selected) tests' passed" "$log"; then exit 0; else exit 65; fi
fi
if [ "$status" -ne 0 ]; then
  echo "the build exited $status; the whole log: $log" >&2
  exit "$status"
fi
grep -q "$done" "$log" && exit 0
echo "no \"$done\" in the output; the whole log: $log" >&2
exit 1
