#!/usr/bin/env bash
# Story 827 (#419): the smoke's audio checks on a locked Mac, with the lock probe faked (SMOKE_LOCK_PROBE), so no
# locked screen and no simulator are needed. Locked: each audio check says "skipped: Mac screen locked" and is
# counted as skipped, never passed; unlocked: they run and nothing is said.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-smoke-lock.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   smoke lock: $1"; }
bad() { echo "FAIL smoke lock: $1"; fail=1; }
printf '#!/usr/bin/env bash\necho "  | |   \\"CGSSessionScreenIsLocked\\"=Yes"\n' >"$tmp/locked"
printf '#!/usr/bin/env bash\necho "  | |   \\"CGSSessionOnConsoleKey\\"=Yes"\n' >"$tmp/unlocked"
chmod +x "$tmp/locked" "$tmp/unlocked"

run() {  # run <probe>: three audio checks and the summary, as the smoke runs them
  SMOKE_LOCK_PROBE=$1 bash -c '
    source scripts/native/smoke-lock.sh
    mac_locked_note "at the start"
    if audio_ok timer; then echo "ran timer"; fi
    if audio_ok breathe; then echo "ran breathe"; fi
    if audio_ok "call (real audio)"; then echo "ran call"; fi
    audio_skips_said'
}

out=$(run "$tmp/locked")
for check in timer breathe "call (real audio)"; do
  if grep -qxF "skip  $check: skipped: Mac screen locked" <<<"$out"; then ok "locked: $check says it is skipped"
  else bad "locked: no skip line for $check: $out"; fi
done
if grep -q '^ran ' <<<"$out"; then bad "locked: an audio check ran: $out"; else ok "locked: no audio check ran"; fi
if grep -qF "smoke: skipped 3 audio check(s), Mac screen locked: timer, breathe, call (real audio); not passed" <<<"$out"
then ok "locked: the summary counts three skipped"
else bad "locked: summary: $out"; fi
if grep -q '^ok ' <<<"$out"; then bad "locked: a skip counted as passed: $out"; else ok "locked: nothing counted as passed"; fi
if grep -qF "the Mac's screen is locked (at the start)" <<<"$out"; then ok "locked: said at the start"
else bad "locked: no note: $out"; fi

out=$(run "$tmp/unlocked")
if [ "$out" = $'ran timer\nran breathe\nran call' ]; then ok "unlocked: every audio check runs, nothing said"
else bad "unlocked: $out"; fi

# Story 1025 (bead qj5y): the real-audio call with the lid closed on the built-in mic, the lid and input probes faked.
printf '#!/usr/bin/env bash\necho "  | |   \\"AppleClamshellState\\" = Yes"\n' >"$tmp/lid-closed"
printf '#!/usr/bin/env bash\necho "  | |   \\"AppleClamshellState\\" = No"\n' >"$tmp/lid-open"
printf '#!/usr/bin/env bash\necho "%s"\n' >"$tmp/no-ioreg"
chmod +x "$tmp/lid-closed" "$tmp/lid-open" "$tmp/no-ioreg"
mic_json() {  # mic_json <transport of the default input>
  printf '{"SPAudioDataType":[{"_items":[{"_name":"Speakers","coreaudio_default_audio_output_device":"spaudio_yes",'
  printf '"coreaudio_device_transport":"coreaudio_device_type_builtin"},{"_name":"Mic","coreaudio_default_audio_input_device":'
  printf '"spaudio_yes","coreaudio_device_transport":"coreaudio_device_type_%s"}]}]}' "$1"
}
mic_json builtin >"$tmp/builtin.json"; mic_json usb >"$tmp/usb.json"
lid_run() {  # lid_run <lid probe> <mic json>: the timer and the real-audio call, unlocked, and the summary
  SMOKE_LOCK_PROBE="$tmp/unlocked" SMOKE_LID_PROBE=$1 SMOKE_MIC_PROBE="cat $2" bash -c '
    source scripts/native/smoke-lock.sh
    if audio_ok timer; then echo "ran timer"; fi
    if audio_ok "call (real audio)" && mic_ok "call (real audio)"; then echo "ran call"; fi
    audio_skips_said'
}
out=$(lid_run "$tmp/lid-closed" "$tmp/builtin.json")
if grep -qxF "skip  call (real audio): skipped: Mac lid closed, the built-in mic hears nothing" <<<"$out" \
  && ! grep -qxF "ran call" <<<"$out"; then ok "lid closed, built-in mic: the real-audio call says it is skipped"
else bad "lid closed, built-in mic: $out"; fi
if grep -qxF "ran timer" <<<"$out"; then ok "lid closed: the timer still runs"; else bad "lid closed: timer: $out"; fi
if grep -qF "smoke: skipped call (real audio), Mac lid closed on the built-in mic; not passed" <<<"$out"
then ok "lid closed: the summary counts it as skipped"
else bad "lid closed: summary: $out"; fi
for case in "lid-open builtin" "lid-closed usb" "no-ioreg builtin"; do
  read -r lid mic <<<"$case"
  out=$(lid_run "$tmp/$lid" "$tmp/$mic.json")
  if [ "$out" = $'ran timer\nran call' ]; then ok "$lid, $mic default input: the real-audio call runs, nothing said"
  else bad "$lid, $mic: $out"; fi
done

exit "$fail"
