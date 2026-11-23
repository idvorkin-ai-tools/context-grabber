#!/usr/bin/env bash
# Run a command for at most <minutes>, then stop it and everything it started, so the build lane around it frees
# (story 1505, bead context-grabber-xmwp). The repo's own copy of mac-driver's `time-limit`, so a Mac without
# ~/gits/mac-driver still times its rungs. Bash, not zsh, so ~/.zshenv (a BUILD_LANES there) never reaches the command
# (context-grabber-jacw).
#   scripts/native/time-limit.sh <minutes> <command>...
# Exits with the command's status, or 124 after saying it stopped it, or 143 when this wrapper itself is stopped.
# TIME_LIMIT_UNIT_S (default 60) is the seconds in a "minute"; the self-test shrinks it.
set -u
if [ $# -lt 2 ] || ! [[ $1 =~ ^[0-9]+$ ]]; then
  echo "usage: time-limit.sh <minutes> <command>..." >&2
  exit 2
fi
mins=$1
shift
unit=${TIME_LIMIT_UNIT_S:-60}
# The command gets its own process group, so stopping it stops xcodebuild and the rest under it.
perl -e 'setpgrp(0, 0); exec @ARGV or die "time-limit: $ARGV[0]: $!\n"' -- "$@" &
pid=$!
fired=$(mktemp -u "${TMPDIR:-/tmp}/time-limit.XXXXXX")
# The watchdog sends TERM, then KILL 5 s later for anything that ignored it, so `wait` below always returns.
(
  # Its own stderr only: cancelling its sleep is the normal end, not news.
  exec 2>/dev/null
  sleep $((mins * unit))
  touch "$fired"
  kill -TERM -- -"$pid" 2>/dev/null
  sleep 5
  kill -KILL -- -"$pid" 2>/dev/null
) &
dog=$!
stop_dog() {
  pkill -P "$dog" 2>/dev/null
  kill "$dog" 2>/dev/null
}
# Stopping this wrapper (a cancelled job, Ctrl-C) stops the command too, so the lane never frees while it runs.
trap 'stop_dog; kill -TERM -- -$pid 2>/dev/null; sleep 5; kill -KILL -- -$pid 2>/dev/null; exit 143' INT TERM HUP
wait "$pid"
rc=$?
if [ ! -e "$fired" ]; then
  stop_dog
  exit "$rc"
fi
wait "$dog" 2>/dev/null
rm -f "$fired"
echo "time-limit: '$*' ran past $mins min; stopped it, so the lane is free again." >&2
echo "time-limit: check the screen and the device before you retry." >&2
exit 124
