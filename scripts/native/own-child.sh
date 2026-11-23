# shellcheck shell=bash
# Sourced by xcodebuild-log.sh. Bead context-grabber-tne1: a background helper that ended by itself long ago (the
# start watchdog stops once the first suite starts, which can be an hour before the run ends) leaves only its number.
# On a busy Mac the process numbers wrap in under half an hour (2026-11-22: about 85000 at 22:00, 70000 by 22:25), so
# that number may by then belong to someone else, and a plain kill of it ended another run's wrapper (the script check
# "a failed locked run" exited 143 with nothing said). So a helper is stopped only while it is still this shell's child.

# kill_own_child <pid>: stop the helper <pid>, and its children, only if it is still a child of this shell ($$).
kill_own_child() {
  local pid=$1 parent
  [ -n "$pid" ] || return 0
  parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  [ "$parent" = "$$" ] || return 0
  pkill -P "$pid" 2>/dev/null
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  return 0
}
