#!/usr/bin/env bash
# Story 1511 (bead context-grabber-yfsz): device-build-check.py against a fake deploys ledger and fake pulled session
# logs (a match, the night's mismatch, no session since the install, a build posted over the air, nothing recorded),
# and deploy.sh with a fake BugKit deploy-all and log puller: each installed device in the ledger, then checked.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d "${TMPDIR:-/tmp}/cg-device-build.XXXXXX")
trap 'rm -rf "$dir"' EXIT
fail=0
out=$dir/out
ok() { echo "ok   device build check: $1"; }
bad() { echo "FAIL device build check: $1"; sed 's/^/     /' "$out"; fail=1; }
has() { if grep -qF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }
exits() { if [ "$status" -eq "$2" ]; then ok "$1"; else echo "     wanted exit $2, got $status"; bad "$1"; fi; }

ledger=$dir/deploys.jsonl logs=$dir/logs
entry() { printf '{"at":"%s","app":"context-grabber","device":"%s","sha":"%s","kind":"%s"}\n' "$1" "$2" "$3" "$4" >>"$ledger"; }
session() {  # device file started sha
  mkdir -p "$logs/$1/logs"
  printf '{"app":"2.0.0","branch":"main","device":"x","sha":"%s","started":"%s","t":95,"type":"session_start"}\n{"t":100,"type":"ui"}\n' \
    "$4" "$3" >"$logs/$1/logs/$2"
}
check() { "$here/device-build-check.py" "$@" --ledger "$ledger" --logs "$logs" >"$out" 2>&1; status=$?; }

# The night of 2026-11-22: the ledger said b3e9de18 at 21:27, the iPad ran 5569178f from 22:56.
entry 2026-11-23T05:27:00Z ipad b3e9de18aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa network
session ipad grabber-20261122-212405.jsonl 2026-11-23T05:24:05Z b3e9de18
session ipad grabber-20261122-225645.jsonl 2026-11-23T06:56:45Z 5569178f
check ipad
has "a session on another build after the install is named" "ipad: MISMATCH: the device runs 5569178f"
has "with the build we think, and when" "but the last install was b3e9de18 at 2026-11-23 05:27:00Z by network"
exits "a mismatch exits 1" 1

entry 2026-11-23T06:55:00Z ipad 5569178fbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb network
check ipad
has "the newest session on the last install matches" "ipad: MATCH 5569178f"
exits "a match exits 0" 0

entry 2026-11-23T07:30:00Z ipad 1111111fcccccccccccccccccccccccccccccccc cable
check ipad
has "no session since the install is no session yet, not an older match" "ipad: NO SESSION YET since the install of 1111111f"
exits "no session yet doesn't fail" 0

entry 2026-11-23T08:00:00Z ipad 2222222fdddddddddddddddddddddddddddddddd ota_posted
session ipad grabber-20261123-001000.jsonl 2026-11-23T08:10:00Z 2222222f
check ipad
has "a build posted over the air that the iPad then runs matches" "ipad: MATCH 2222222f (posted over the air"
exits "an over-the-air build doesn't fail" 0

check phone
has "a device with no install recorded is unknown" "phone: UNKNOWN: no install recorded"
exits "unknown doesn't fail" 0

entry 2026-11-23T08:00:00Z phone 3333333feeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee cable
check phone
has "an install with no pulled session is unknown" "phone: UNKNOWN: no session log pulled"

# just deploy: a fake deploy-all that installs the iPad and refuses the phone; a fake puller that writes the iPad's
# next session on the installed commit; the check then matches.
repo=$dir/repo logs=$dir/logs2
git init -q "$repo" && git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
want=$(git -C "$repo" rev-parse HEAD)
cat >"$dir/deploy-all" <<F
#!/usr/bin/env bash
echo "args: \$*"
echo "== ipad-air-11-inch-m3: installed and launched"
echo "== iphone-17-pro: install failed: error 1"
F
cat >"$dir/pull" <<F
#!/usr/bin/env bash
mkdir -p "$logs/ipad/logs"
sleep 1; printf '{"sha":"%s","started":"%s","type":"session_start"}\n' "${want:0:8}" "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$logs/ipad/logs/grabber-29991231-235959.jsonl"
F
chmod +x "$dir/deploy-all" "$dir/pull"
: >"$dir/deploys2.jsonl"
DEPLOY_ALL=$dir/deploy-all PULL_LOGS=$dir/pull DEPLOY_REPO=$repo DEPLOY_CHECK_WAIT=30 LEAD_TIMES_DEPLOYS=$dir/deploys2.jsonl \
  GRABBER_LOGS=$logs "$here/deploy.sh" --only ipad,phone >"$out" 2>&1
status=$?
has "deploy names devices by their folders" "--only ipad-air-11-inch-m3,iphone-17-pro"
if grep -q "\"device\":\"ipad\",\"sha\":\"$want\",\"kind\":\"network\"" "$dir/deploys2.jsonl"; then ok "the installed device is in the ledger"; else cp "$dir/deploys2.jsonl" "$out"; bad "the installed device is in the ledger"; fi
if grep -q '"device":"phone"' "$dir/deploys2.jsonl"; then cp "$dir/deploys2.jsonl" "$out"; bad "a refused install isn't recorded"; else ok "a refused install isn't recorded"; fi
has "deploy then checks the device's next session" "ipad: MATCH ${want:0:8}"
exits "a deploy that matches exits as deploy-all did" 0

exit $fail
