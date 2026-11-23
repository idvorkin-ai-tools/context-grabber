#!/usr/bin/env bash
# Story 1511 (bead context-grabber-yfsz): the network install of this checkout on Igor's paired devices through BugKit's
# deploy-all, with each device that took it recorded in the deploys ledger (record-deploy.sh, kind `network`), then the
# device's next session checked against it (device-build-check.py) so a build that isn't the one we installed is named.
# Usage: deploy.sh [--only ipad|phone|<device folder>[,…]] [any other deploy-all option]
#   ipad and phone stand for the folders BugKit's listener uses (ipad-…, iphone-…); a folder name passes as it is.
# DEPLOY_ALL: the BugKit script (default ~/gits/bug-kit/scripts/deploy-all.sh). DEPLOY_CHECK_WAIT: seconds to wait for
# the device's next session after the install (default 120; 0 skips the check). PULL_LOGS: the log puller
# (default scripts/native/pull-logs.sh).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
deploy_all=${DEPLOY_ALL:-$HOME/gits/bug-kit/scripts/deploy-all.sh}
pull_logs=${PULL_LOGS:-$here/pull-logs.sh}
wait_s=${DEPLOY_CHECK_WAIT:-120}
[ -x "$deploy_all" ] || { echo "deploy: no BugKit deploy-all at $deploy_all" >&2; exit 69; }

args=()
while [ $# -gt 0 ]; do
  case $1 in
    --only)
      only=""
      IFS=, read -ra names <<<"${2:-}"
      for n in "${names[@]}"; do
        case $n in
          ipad) n=$(ls -d ~/tmp/agent/bugs/context-grabber/ipad-* 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null); n=${n:-ipad-air-11-inch-m3} ;;
          phone | iphone) n=$(ls -d ~/tmp/agent/bugs/context-grabber/iphone-* 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null); n=${n:-iphone-17-pro} ;;
        esac
        only+=${only:+,}$n
      done
      args+=(--only "$only"); shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

# deploy-all builds the checkout BugKit's config names for the app (not necessarily this one), so that commit is recorded.
repo=${DEPLOY_REPO:-$(jq -r '.apps[] | select(.name == "context-grabber") | .repo' \
  "${BUG_KIT_CONFIG:-$HOME/.config/bug-kit/apps.json}" 2>/dev/null)}
repo=${repo/#\~/$HOME}; repo=${repo:-$here/../..}
sha=$(git -C "$repo" rev-parse HEAD) || { echo "deploy: can't read the commit of $repo" >&2; exit 1; }
[ "$repo" -ef "$here/../.." ] || echo "deploy: BugKit builds $repo at ${sha:0:8}, not this checkout"
out=$(mktemp "${TMPDIR:-/tmp}/cg-deploy.XXXXXX")
trap 'rm -f "$out"' EXIT
# The install time is the deploy's start: deploy-all launches the app, starting its session, before it returns.
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
"$deploy_all" context-grabber "${args[@]}" 2>&1 | tee "$out"
status=${PIPESTATUS[0]}

# Each device that reports "installed" (launched or not) is in the ledger; a dry run installs nothing.
devices=()
while IFS= read -r line; do
  name=${line#== }; name=${name%%:*}
  case $name in ipad-*) dev=ipad ;; iphone-*) dev=phone ;; *) continue ;; esac
  RECORD_DEPLOY_AT=$started "$here/record-deploy.sh" "$dev" "$sha" network
  devices+=("$dev")
done < <(grep -E '^== [^:]+: installed' "$out" | grep -v 'dry run')

[ ${#devices[@]} -gt 0 ] && [ "$wait_s" -gt 0 ] || exit "$status"
# The install launched the app, which starts a session naming its build; pull until each device's shows up.
echo "deploy: checking the build ${devices[*]} report (up to ${wait_s} s)"
deadline=$((SECONDS + wait_s))
while :; do
  "$pull_logs" >/dev/null 2>&1 || true
  check=$("$here/device-build-check.py" "${devices[@]}"); code=$?
  if ! grep -q 'NO SESSION YET\|UNKNOWN' <<<"$check" || [ $SECONDS -ge $deadline ]; then break; fi
  sleep 15
done
echo "$check"
[ "$code" -eq 1 ] && exit 1
exit "$status"
