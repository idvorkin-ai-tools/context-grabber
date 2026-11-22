# shellcheck shell=bash
# Sourced by sim-smoke.sh, sim-boot.sh, xcodebuild-log.sh, test-ladder.sh and the contract tests' recipe.
# Story 827 (#419): the simulator smoke's audio checks while the Mac's screen is locked. A locked Mac starves the
# simulator's audio (timer cues late or empty, keepalive ok:false, breathing silent), and the rerun cost 5 to 12
# minutes, so those checks are skipped and said to be, never counted as passed. Sourced by sim-smoke.sh.
# SMOKE_LOCK_PROBE: the command whose output says whether the screen is locked (default `ioreg -n Root -d1`); the
# script check fakes it.

audio_skipped=""
audio_skips=0

# Read as BugKit's signing guard reads it (scripts/signing-guard.sh): ioreg's CGSSessionScreenIsLocked, Yes or true.
# A probe that can't be read counts as unlocked, unlike the guard: Linux has no ioreg, and its script checks run this.
mac_locked() {
  local state
  # shellcheck disable=SC2086  # the probe is a command and its words
  state=$(${SMOKE_LOCK_PROBE:-ioreg -n Root -d1} 2>/dev/null)
  # Whole, then matched: grep -q on a pipe could stop ioreg early, and pipefail would read that as unlocked.
  grep -qE '"CGSSessionScreenIsLocked"[[:space:]]*=[[:space:]]*(Yes|true)' <<<"$state"
}

# Story 1022 (bead context-grabber-208e): nothing that tests on a simulator, or boots one, starts on a locked Mac: its
# audio server starves and the app aborts when a test opens the mic, each crash a dialog on Igor's screen.
# wait_unlocked <what>: true at once when unlocked; locked, says so once and looks again every SIM_LOCK_POLL seconds (5)
# for up to SIM_LOCK_WAIT (120: the signing guard's 24 looks 5 s apart), true once unlocked; still locked, it says
# <what> didn't start and returns 75, for the caller to exit with.
wait_unlocked() {
  local what=${1:-the simulator run} limit=${SIM_LOCK_WAIT:-120} poll=${SIM_LOCK_POLL:-5} waited=0
  mac_locked || return 0
  [ "$limit" -le 0 ] || echo "the Mac's screen is locked: waiting up to $limit s for it to be unlocked before $what" >&2
  while [ "$waited" -lt "$limit" ]; do
    sleep "$poll"
    waited=$((waited + poll))
    if ! mac_locked; then
      echo "the Mac's screen is unlocked: starting $what" >&2
      return 0
    fi
  done
  echo "the Mac's screen is locked, so $what didn't start (waited $waited s): a locked Mac starves the simulator's audio" \
    "and the app can crash when a test opens the mic (story 1022); unlock it and rerun" >&2
  return 75
}

# audio_ok <check>: true to run it; false while the screen is locked, with a skip line that counts it.
audio_ok() {
  mac_locked || return 0
  echo "skip  $1: skipped: Mac screen locked"
  audio_skips=$((audio_skips + 1))
  audio_skipped="${audio_skipped:+$audio_skipped, }$1"
  return 1
}

# Story 1025 (bead context-grabber-qj5y): the simulator's microphone is the Mac's default input, and with the lid closed
# the built-in microphone delivers exact zeros, so the real-audio call re-arms the mic, still hears nothing and files an
# automatic report. mac_mic_deaf: true when the lid is closed and the default input is the built-in microphone.
# SMOKE_LID_PROBE (default `ioreg -r -k AppleClamshellState -d 1`) and SMOKE_MIC_PROBE (default
# `system_profiler SPAudioDataType -json`) are the commands that say so; the script check fakes them. A probe that
# can't be read, or a key that isn't there (Linux, a Mac without a lid), counts as hearing, so the call runs.
mac_mic_deaf() {
  local lid mic
  # shellcheck disable=SC2086  # each probe is a command and its words
  lid=$(${SMOKE_LID_PROBE:-ioreg -r -k AppleClamshellState -d 1} 2>/dev/null)
  grep -qE '"AppleClamshellState"[[:space:]]*=[[:space:]]*Yes' <<<"$lid" || return 1
  # shellcheck disable=SC2086
  mic=$(${SMOKE_MIC_PROBE:-system_profiler SPAudioDataType -json} 2>/dev/null)
  jq -e '[.SPAudioDataType[]?._items[]? | select(.coreaudio_default_audio_input_device == "spaudio_yes")
    | .coreaudio_device_transport] | any(. == "coreaudio_device_type_builtin")' <<<"$mic" >/dev/null 2>&1
}

mic_skipped=""
# mic_ok <check>: true to run it; false while the lid is closed on the built-in mic, with a skip line that counts it.
mic_ok() {
  mac_mic_deaf || return 0
  echo "skip  $1: skipped: Mac lid closed, the built-in mic hears nothing"
  mic_skipped="${mic_skipped:+$mic_skipped, }$1"
  return 1
}

# The run's last word on them, before smoke-lib's own: nothing when none was skipped.
audio_skips_said() {
  [ -z "$mic_skipped" ] \
    || echo "smoke: skipped $mic_skipped, Mac lid closed on the built-in mic; not passed, rerun with the lid open (story 1025)"
  [ "$audio_skips" -gt 0 ] || return 0
  echo "smoke: skipped $audio_skips audio check(s), Mac screen locked: $audio_skipped; not passed, rerun unlocked (#419)"
}

# Said at both ends, as the screen can lock mid-run: a check already running when it locked can still fail.
mac_locked_note() {
  mac_locked && echo "smoke: the Mac's screen is locked ($1): the audio checks are skipped from here (#419)"
  return 0
}
