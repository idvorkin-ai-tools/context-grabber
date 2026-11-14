#!/usr/bin/env bash
# Story 827 (#419): the smoke's audio checks on a locked Mac, with the lock probe faked (SMOKE_LOCK_PROBE), so no
# locked screen and no simulator are needed. Locked: each audio check says "skipped: Mac screen locked" and is
# counted as skipped, never passed; unlocked: they run and nothing is said. Then that sim-smoke.sh asks before each.
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

# The smoke asks before each audio section, and says how many it skipped before its last line.
smoke=scripts/native/sim-smoke.sh
# shellcheck disable=SC2016  # the lines as written in the script, not expanded
for wiring in 'source "$(dirname "$0")/smoke-lock.sh"' 'if want timer && audio_ok timer; then' \
  'if want breathe && audio_ok breathe; then' 'if audio_ok "call (real audio)"; then call_check "real audio" ""; fi' \
  'audio_skips_said'; do
  if grep -qF -- "$wiring" "$smoke"; then ok "sim-smoke.sh: $wiring"; else bad "sim-smoke.sh lacks: $wiring"; fi
done
exit "$fail"
