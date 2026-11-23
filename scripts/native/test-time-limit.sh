#!/usr/bin/env bash
# Story 1505 (context-grabber-xmwp): the repo's own rung time limit. A command that finishes keeps its status, one that
# runs past its limit is stopped with everything it started (exit 124), a bad call is refused, and ~/.zshenv never
# reaches the command. A "minute" is one second here (TIME_LIMIT_UNIT_S).
cd "$(dirname "$0")/../.." || exit 1
tl=scripts/native/time-limit.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/time-limit-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
export TIME_LIMIT_UNIT_S=1

"$tl" 5 bash -c 'exit 7'
status=$?
if [ "$status" -eq 7 ]; then ok "a command that finishes keeps its status"; else bad "a command that finishes keeps its status, exit $status"; fi

# A hang that started a child of its own: both go when the limit fires, and the wrapper says so.
start=$(date +%s)
"$tl" 1 bash -c 'sleep 300 & echo $! >"$1"; sleep 300' _ "$tmp/child" 2>"$tmp/err"
status=$?
took=$(($(date +%s) - start))
if [ "$status" -eq 124 ]; then ok "a hang past its limit: exit 124"; else bad "a hang past its limit: exit 124, got $status"; fi
if [ "$took" -lt 20 ]; then ok "a hang past its limit: stopped in seconds"; else bad "a hang past its limit: stopped in seconds, took ${took}s"; fi
if kill -0 "$(cat "$tmp/child")" 2>/dev/null; then bad "a hang past its limit: its child stopped too"; else ok "a hang past its limit: its child stopped too"; fi
if grep -q "ran past 1 min; stopped it, so the lane is free again" "$tmp/err"; then ok "a hang past its limit: says so"
else bad "a hang past its limit: says so ($(cat "$tmp/err"))"; fi

# A child that ignores TERM still goes, by the KILL that follows.
"$tl" 1 bash -c 'trap "" TERM; sleep 300' 2>/dev/null
status=$?
if [ "$status" -eq 124 ]; then ok "a command that ignores TERM: stopped all the same"; else bad "a command that ignores TERM: stopped all the same, exit $status"; fi

"$tl" soon true 2>/dev/null
status=$?
if [ "$status" -eq 2 ]; then ok "minutes that aren't a number: refused"; else bad "minutes that aren't a number: refused, exit $status"; fi
"$tl" 5 2>/dev/null
status=$?
if [ "$status" -eq 2 ]; then ok "no command: refused"; else bad "no command: refused, exit $status"; fi

# context-grabber-jacw: the lane's BUILD_LANES survives, whatever ~/.zshenv says (bash never reads it).
mkdir -p "$tmp/home"
echo 'export BUILD_LANES=6' >"$tmp/home/.zshenv"
lanes=$(HOME="$tmp/home" BUILD_LANES=2 "$tl" 5 bash -c 'echo "$BUILD_LANES"')
if [ "$lanes" = 2 ]; then ok "the lane count reaches the command unchanged"; else bad "the lane count reaches the command unchanged, got $lanes"; fi

exit $fail
