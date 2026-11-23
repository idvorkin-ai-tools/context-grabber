#!/usr/bin/env bash
# #1038 (story 1016): one line in the deploys ledger for a build that reached a device or TestFlight, so the lead-time
# and ladder reports can tell merged from on a device. The ledger is LEAD_TIMES_DEPLOYS (default
# ~/tmp/agent/notes/lead-times/deploys.jsonl), outside the repo: it names devices, and the repo is public.
# Usage: record-deploy.sh <phone|ipad|testflight> <sha> [cable|network|ota_posted|testflight_upload|testflight_available]
#   cable                 installed over the cable (just native-run-device); the default
#   network               installed over the network by BugKit's deploy-all (just deploy; story 1511)
#   ota_posted            posted to the Cockpit's /builds for the iPad (just ota); installed only when Igor taps it
#   testflight_upload     uploaded to App Store Connect (just testflight); not on a device yet
#   testflight_available  TestFlight offers the build (said by hand once it does: Apple's processing takes minutes)
# RECORD_DEPLOY_AT: the install's time (UTC, %Y-%m-%dT%H:%M:%SZ) when it isn't now, e.g. deploy.sh's start, since
# deploy-all launches the app (and its session starts) before the install is recorded (story 1511).
set -uo pipefail
device=${1:?usage: record-deploy.sh <phone|ipad|testflight> <sha> [kind]} sha=${2:?a commit sha} kind=${3:-cable}
case $kind in cable | network | ota_posted | testflight_upload | testflight_available) ;; *) echo "record-deploy: no kind $kind" >&2; exit 2 ;; esac
ledger=${LEAD_TIMES_DEPLOYS:-$HOME/tmp/agent/notes/lead-times/deploys.jsonl}
mkdir -p "${ledger%/*}" || exit 1
printf '{"at":"%s","app":"context-grabber","device":"%s","sha":"%s","kind":"%s"}\n' \
  "${RECORD_DEPLOY_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" "$device" "$sha" "$kind" >>"$ledger"
echo "record-deploy: $kind of ${sha:0:8} to $device, in $ledger"
