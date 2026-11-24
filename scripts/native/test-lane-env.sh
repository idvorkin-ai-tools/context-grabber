#!/usr/bin/env bash
# Host test (bead context-grabber-2l07): the lane script tests isolate themselves from the caller's lane settings.
# AGENTS.md has every ladder run set SIM to the iPad, and lanes run with BUILD_LANES/HOST_LANES and their waits set;
# a script test that read those from its caller failed 14 checks under SIM="iPad Pro 11-inch (M5)". Each test here
# runs with a hostile environment and must pass exactly as it does clean.
set -uo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-lane-env-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
for t in test-build-lane.sh test-sim-lane.sh test-host-lane.sh; do
  if env SIM="iPad Pro 11-inch (M5)" WHITEBOARD_SIM="iPhone 17" BUILD_LANES=1 BUILD_LANE=3 BUILD_LANE_PORT_OFFSET=30 \
    HOST_LANES=1 HOST_LANE=2 BUILD_LANE_WAIT=1 BUILD_LANE_POLL=1 BUILD_LANE_CLONE_WAIT=1 BUILD_LANE_REFRESH_WAIT=1 \
    XCODEBUILD_IDLE_WAIT=1 XCODEBUILD_IDLE_POLL=1 BUILD_LOCK_DIR="$tmp/caller-locks" \
    bash "scripts/native/$t" >"$tmp/out" 2>&1; then
    echo "ok   $t passes with the caller's SIM and lane settings set"
  else
    echo "FAIL $t under the caller's SIM and lane settings:"
    grep '^FAIL' "$tmp/out" | sed 's/^/     /'
    fail=1
  fi
done
exit $fail
