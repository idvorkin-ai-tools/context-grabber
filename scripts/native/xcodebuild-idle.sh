#!/usr/bin/env bash
# Never start a simulator rung while another xcodebuild runs: startup waits fail under the load, so a run under
# contention proves nothing (docs/TESTING.md, story 680). Waits for every xcodebuild on this Mac to finish, saying so,
# and refuses with 75 after XCODEBUILD_IDLE_WAIT seconds (default half an hour).
# Usage: xcodebuild-idle.sh   — before anything that drives the simulator
set -uo pipefail
limit=${XCODEBUILD_IDLE_WAIT:-1800}
poll=${XCODEBUILD_IDLE_POLL:-15}
waited=0
pgrep -x xcodebuild >/dev/null || exit 0
echo "another xcodebuild is running: waiting up to ${limit}s, because a simulator run under contention counts as failed"
while pgrep -x xcodebuild >/dev/null; do
  if [ "$waited" -ge "$limit" ]; then
    echo "refused: another xcodebuild was still running after ${waited}s; nothing started" >&2
    exit 75
  fi
  sleep "$poll"
  waited=$((waited + poll))
done
echo "no other xcodebuild now, after ${waited}s"
