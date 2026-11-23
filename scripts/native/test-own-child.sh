#!/usr/bin/env bash
# Bead context-grabber-tne1: xcodebuild-log.sh stops its watchdogs at the end of a run with kill_own_child, which stops
# a helper only while it is still this shell's child. A helper that ended long ago left a number another process may
# have by now (the numbers wrap in under half an hour on a busy Mac), and a plain kill of it ended that process.
set -uo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=scripts/native/own-child.sh
. scripts/native/own-child.sh
tmp=$(mktemp -d)
trap 'kill "$(cat "$tmp/decoy" 2>/dev/null)" 2>/dev/null; rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
alive() { kill -0 "$1" 2>/dev/null; }

# Someone else's process that now holds a number a helper of ours once had: started from a subshell that ends, so its
# parent is no longer this shell, as with a number that was reused.
(sleep 60 >/dev/null 2>&1 & echo $! >"$tmp/decoy")
decoy=$(cat "$tmp/decoy")
alive "$decoy" && ok "a process that isn't this shell's child is running" || bad "the decoy didn't start"
kill_own_child "$decoy"
sleep 0.2
alive "$decoy" && ok "and kill_own_child leaves it alone" || bad "kill_own_child ended a process that wasn't its child"

# Our own helper, with a child of its own, as a watchdog sleeping inside its loop.
(sleep 60 & wait) >/dev/null 2>&1 &
own=$!
sleep 0.2
grandchild=$(pgrep -P "$own" | head -1)
kill_own_child "$own"
sleep 0.2
alive "$own" && bad "kill_own_child left its own helper running" || ok "kill_own_child stops this shell's own helper"
[ -n "$grandchild" ] && ! alive "$grandchild" && ok "and the helper's own children" ||
  bad "the helper's child ${grandchild:-(none found)} is still running"

# A helper that ended by itself: nothing to stop, and no error.
(exit 0) &
gone=$!
wait "$gone" 2>/dev/null
kill_own_child "$gone" && ok "a helper that already ended is skipped quietly" || bad "kill_own_child failed on an ended helper"
kill_own_child "" && ok "and so is an empty number" || bad "kill_own_child failed on an empty number"

exit "$fail"
