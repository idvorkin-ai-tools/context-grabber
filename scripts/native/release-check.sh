#!/usr/bin/env bash
# Story 1519 (bead context-grabber-6ocd): ContextCore compiled the way an archive compiles it (Release, -O), run by
# `just pre-merge`. The debug builds every other rung uses never run the optimizer, so a compiler crash in it (Swift
# 6.4.2's CopyPropagation on BoardReview.movedWithoutAim, 2026-11-24) only surfaced in `just ota`, after the merge.
# Skipped when the branch leaves native/ContextCore as origin/main has it; RELEASE_CHECK=1 builds anyway.
# RELEASE_CHECK_BUILD replaces the build command (the host test's fake). PRE_MERGE_REMOTE overrides origin.
# The build takes a host slot and the checkout's own .build, so a slot's second run is incremental (~1 min; cold ~2).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
here=$(cd "$(dirname "$0")" && pwd)
if [ "${RELEASE_CHECK:-}" != 1 ]; then
  git fetch -q "$remote" main 2>/dev/null || true
  if git diff --quiet "$remote/main...HEAD" -- native/ContextCore 2>/dev/null; then
    echo "ok   release-check: native/ContextCore unchanged from $remote/main, Release build skipped"
    exit 0
  fi
fi
build=${RELEASE_CHECK_BUILD:-"cd native/ContextCore && '$here/host-lane.sh' run swift build -c release"}
if out=$(bash -c "$build" 2>&1); then
  echo "ok   release-check: ContextCore's Release build passes"
else
  grep -E "error:|While running pass|fatal error" <<<"$out" | head -8 | sed 's/^/     /'
  echo "FAIL release-check: ContextCore doesn't build in Release (-O), as an archive (just ota, TestFlight) compiles it"
  exit 1
fi
