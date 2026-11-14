# shellcheck shell=bash
# Story 827 (#419): the simulator smoke's audio checks while the Mac's screen is locked. A locked Mac starves the
# simulator's audio (timer cues late or empty, keepalive ok:false, breathing silent), and the rerun cost 5 to 12
# minutes, so those checks are skipped and said to be, never counted as passed. Sourced by sim-smoke.sh.
# SMOKE_LOCK_PROBE: the command whose output says whether the screen is locked (default `ioreg -n Root -d1`); the
# script check fakes it.

audio_skipped=""
audio_skips=0

mac_locked() {
  # shellcheck disable=SC2086  # the probe is a command and its words
  case "$(${SMOKE_LOCK_PROBE:-ioreg -n Root -d1} 2>/dev/null)" in
    *'"CGSSessionScreenIsLocked"=Yes'*) return 0 ;;
  esac
  return 1
}

# audio_ok <check>: true to run it; false while the screen is locked, with a skip line that counts it.
audio_ok() {
  mac_locked || return 0
  echo "skip  $1: skipped: Mac screen locked"
  audio_skips=$((audio_skips + 1))
  audio_skipped="${audio_skipped:+$audio_skipped, }$1"
  return 1
}

# The run's last word on them, before smoke-lib's own: nothing when none was skipped.
audio_skips_said() {
  [ "$audio_skips" -gt 0 ] || return 0
  echo "smoke: skipped $audio_skips audio check(s), Mac screen locked: $audio_skipped; not passed, rerun unlocked (#419)"
}

# Said at both ends, as the screen can lock mid-run: a check already running when it locked can still fail.
mac_locked_note() {
  mac_locked && echo "smoke: the Mac's screen is locked ($1): the audio checks are skipped from here (#419)"
  return 0
}
