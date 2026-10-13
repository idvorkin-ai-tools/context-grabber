#!/usr/bin/env bash
# Runs an xcodebuild command line, keeping its whole output in native/Build/logs/<name>.log and putting
# xcbeautify's digest on screen: the tasks with warnings or errors, and the test results. Succeeds only if the
# command exits 0 and the log carries the <done> line ("BUILD SUCCEEDED", "TEST SUCCEEDED"); a grep on exit codes
# alone would pass a failed build through a pipe. Without xcbeautify the screen gets the error and result lines instead.
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
# Xcode's account tokens never reach the log or the screen.
"$@" 2>&1 | sed -E 's/(X-Apple-GS-Token|DSESSIONID)([:=] *)[^ ;]+/\1\2<filtered>/g' | tee "$log" | "${show[@]}"
# A wrapper may fail a build that printed its done line: BugKit's signing guard exits 78 on "No Accounts".
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  echo "the build exited $status; the whole log: $log" >&2
  exit "$status"
fi
grep -q "$done" "$log" && exit 0
echo "no \"$done\" in the output; the whole log: $log" >&2
exit 1
