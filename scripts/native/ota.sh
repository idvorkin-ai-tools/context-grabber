#!/usr/bin/env bash
# `just ota`: main, development-signed, on the Cockpit's /builds page, from where the iPad installs it over the air
# (bead context-grabber-omes, stories 1027-1029; spec docs/superpowers/specs/2026-11-22-ota-builds-design.md;
# docs/DEPLOYING.md). Archives main as `just testflight --export-only` does, exports it signed for development under
# the signing lock and BugKit's screen-lock guard, checks the profile lists the iPad, and copies it to the Cockpit.
#
# Usage: ota.sh [--dry-run] [--check-ipa <ipa>]
#   --dry-run          the plan: the commit, the package, the iPad check and the destination; switches, builds,
#                      signs and copies nothing
#   --check-ipa <ipa>  only check that an .ipa's profiles list the iPad (and say when they expire)
#
# Environment: OTA_HOST (developer@c-5004) and OTA_DIR (gits/igor2/cockpit-data/builds), where the package goes.
# The iPad's UDID comes from the gitignored scripts/native/ipad-udid.local (never printed whole).
# Exits: 0 built and copied; 64 usage; 65 main can't be checked out or pulled; 66 no such .ipa; 75 another OTA is
# running or main advanced since the watcher polled; 78 a person must act (ID, profile or Xcode account);
# 80 the Mac stayed locked (BugKit's guard); a failed build's own code otherwise.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
cd "$repo" || exit 1
args=("$@")

dry_run=0 check_ipa=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --check-ipa)
      check_ipa=${2:-}
      [[ -n "$check_ipa" && "$check_ipa" != -* ]] || {
        echo "ota: --check-ipa needs a path" >&2
        exit 64
      }
      shift
      ;;
    -h | --help)
      sed -n '2,16p' "$repo/scripts/native/ota.sh" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ota: unknown argument $1 (--help)" >&2
      exit 64
      ;;
  esac
  shift
done

host=${OTA_HOST:-developer@c-5004}
dir=${OTA_DIR:-gits/igor2/cockpit-data/builds}
lock=$HOME/tmp/agent/locks/ota.lock
timings=$HOME/tmp/agent/notes/ota-timings.log

ipad=""
[ ! -r scripts/native/ipad-udid.local ] || ipad=$(tr -d '[:space:]' <scripts/native/ipad-udid.local)
if [ -z "$ipad" ]; then
  echo "ota: no iPad id: write it to scripts/native/ipad-udid.local (gitignored; docs/DEPLOYING.md \"Adding a device\")" >&2
  exit 78
fi
shown_ipad=…
[ "${#ipad}" -le 8 ] || shown_ipad="${ipad:0:4}…${ipad: -4}"

# Every embedded profile in the package (the app, the widgets, the share extension) must list the iPad.
check_profiles() ( # <ipa>
  local ipa=$1 tmp profiles p name expires missing=0 want plist
  want=$(tr 'a-z' 'A-Z' <<<"$ipad")
  tmp=$(mktemp -d) || return 78
  trap 'rm -rf "$tmp"' EXIT
  plist=$tmp/profile.plist
  if ! unzip -qo "$ipa" 'Payload/*/embedded.mobileprovision' -d "$tmp" 2>/dev/null ||
    ! profiles=$(find "$tmp/Payload" -name embedded.mobileprovision | sort) ||
    [ -z "$profiles" ]; then
    echo "ota: can't extract and enumerate the embedded profiles in $ipa (is it a device build?)" >&2
    return 78
  fi
  while IFS= read -r p; do
    if ! security cms -D -i "$p" >"$plist" 2>/dev/null ||
      ! name=$(plutil -extract Name raw "$plist" 2>/dev/null) ||
      ! expires=$(plutil -extract ExpirationDate raw "$plist" 2>/dev/null); then
      echo "ota: can't read the profile ${p#"$tmp"/}" >&2
      missing=1
      continue
    fi
    if ! plutil -extract ProvisionedDevices json -o - "$plist" 2>/dev/null | tr 'a-z' 'A-Z' | grep -F "\"$want\"" >/dev/null; then
      echo "ota: the profile \"$name\" doesn't list the iPad ($shown_ipad): register it and build again (docs/DEPLOYING.md \"Adding a device\")" >&2
      missing=1
      continue
    fi
    echo "ota: profile \"$name\" lists the iPad ($shown_ipad), expires $expires"
  done <<<"$profiles"
  [ "$missing" = 0 ] || return 78
)

if [ -n "$check_ipa" ]; then
  [ -f "$check_ipa" ] || {
    echo "ota: no such .ipa: $check_ipa" >&2
    exit 66
  }
  check_profiles "$check_ipa"
  exit
fi

if [ "$dry_run" = 1 ]; then
  branch=$(git branch --show-current)
  plan=$(scripts/native/testflight.sh --export-only --dry-run --allow-dirty) || exit
  stamp=$(sed -n 's#^  export:  native/Build/Export/##p' <<<"$plan")
  echo "ota: dry run: would switch to main$([ "$branch" = main ] || echo " (now on ${branch:-a detached HEAD})") and pull, then:"
  echo "  build:   $(head -1 <<<"$plan" | sed 's/^testflight: //') (after the pull it may be newer)"
  echo "  archive: native/Build/Archives/$stamp.xcarchive, as just testflight --export-only"
  echo "  export:  native/Build/Export/$stamp-dev, development-signed"
  echo "  check:   the profiles list the iPad ($shown_ipad)"
  echo "  copy:    $host:$dir/grabber-${stamp##*-}.ipa"
  exit 0
fi

# One ota at a time on this Mac, by hand or from the watcher: a second one stops at once (lockf's 75).
if [ -z "${OTA_LOCKED:-}" ]; then
  mkdir -p "$(dirname "$lock")" || exit
  OTA_LOCKED=1 exec lockf -k -t 0 "$lock" "$repo/scripts/native/ota.sh" ${args[@]+"${args[@]}"}
fi

t0=$(date +%s)
if [ "$(git branch --show-current)" != main ]; then
  git checkout -q main || {
    echo "ota: can't check out main here (is it checked out in another worktree?)" >&2
    exit 65
  }
fi
git fetch -q origin +refs/heads/main:refs/remotes/origin/main || exit 65
selected=$(git rev-parse refs/remotes/origin/main) || exit 65
if [ -n "${OTA_EXPECTED_SHA:-}" ] && [ "$selected" != "$OTA_EXPECTED_SHA" ]; then
  echo "ota: origin/main advanced since the watcher polled" >&2
  exit 75
fi
if ! git merge -q --ff-only "$selected" || [ "$(git rev-parse HEAD)" != "$selected" ]; then
  echo "ota: main can't be pulled fast-forward" >&2
  exit 65
fi
plan=$(scripts/native/testflight.sh --export-only --dry-run) || exit
stamp=$(sed -n 's#^  export:  native/Build/Export/##p' <<<"$plan")
[ -n "$stamp" ] || {
  echo "ota: no stamp in testflight's plan:" >&2
  echo "$plan" >&2
  exit 1
}
mkdir -p native/Build/logs
tf_log=native/Build/logs/ota-testflight.log
echo "ota: archiving $stamp (just testflight --export-only; $tf_log)"
just testflight --export-only >"$tf_log" 2>&1 || {
  rc=$?
  tail -20 "$tf_log" >&2
  exit "$rc"
}
t1=$(date +%s)
archive=native/Build/Archives/$stamp.xcarchive

out=native/Build/Export/$stamp-dev
rm -rf "$out"
mkdir -p "$out"
team=$(sed -n 's/^ *DEVELOPMENT_TEAM: *//p' native/project.yml | head -1)
cat >"$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>debugging</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>$team</string>
	<key>thinning</key><string>&lt;none&gt;</string>
</dict>
</plist>
EOF
guard=native/Build/SourcePackages/checkouts/bug-kit/scripts/signing-guard.sh
echo "ota: exporting development-signed (native/Build/logs/ota-export.log)"
scripts/native/xcodebuild-log.sh ota-export "EXPORT SUCCEEDED" lockf "$HOME/tmp/agent/locks/xcode-signing.lock" "$guard" \
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out" -exportOptionsPlist "$out/ExportOptions.plist" \
  -allowProvisioningUpdates >/dev/null || exit
ipa=$out/GrabberNative.ipa
[ -f "$ipa" ] || {
  echo "ota: the export left no $ipa" >&2
  exit 1
}
t2=$(date +%s)
check_profiles "$ipa" || exit

# What the package says it is, read back rather than assumed.
plist=$(mktemp) || exit
trap 'rm -f "$plist"' EXIT
if ! unzip -p "$ipa" 'Payload/GrabberNative.app/Info.plist' >"$plist" ||
  ! version=$(plutil -extract CFBundleShortVersionString raw "$plist") ||
  ! build=$(plutil -extract CFBundleVersion raw "$plist") ||
  ! sha=$(plutil -extract GitSha raw "$plist") ||
  ! [[ "$sha" =~ ^[0-9a-f]+$ ]] ||
  [ "$(git rev-parse --verify "$sha^{commit}" 2>/dev/null)" != "$selected" ]; then
  echo "ota: can't verify that the package was built from $selected" >&2
  exit 1
fi
sum=$(shasum -a 256 "$ipa" | cut -c1-16) || exit
published="$dir/grabber-$sha.ipa"
stage="$dir/.grabber-$sha.ipa.$$.$RANDOM.part"
remote=(ssh -o BatchMode=yes -o ConnectTimeout=15 -- "$host")
apostrophe="'"
escaped_apostrophe="'\"'\"'"
quoted_stage="'${stage//"$apostrophe"/$escaped_apostrophe}'"
quoted_published="'${published//"$apostrophe"/$escaped_apostrophe}'"
dest="$host:$published"
t3=$(date +%s)
scp -q -o BatchMode=yes -o ConnectTimeout=15 -- "$ipa" "$host:$stage" &&
  "${remote[@]}" "mv -f -- $quoted_stage $quoted_published" || {
  rc=$?
  "${remote[@]}" "rm -f -- $quoted_stage" >/dev/null 2>&1 || :
  echo "ota: the copy to $dest failed; the package is at $ipa" >&2
  exit "$rc"
}
t4=$(date +%s)
times="archive and App Store export $((t1 - t0)) s, development export $((t2 - t1)) s, check $((t3 - t2)) s, copy $((t4 - t3)) s, total $((t4 - t0)) s"
echo "ota: $version ($build) $sha -> $dest (sha256 $sum)"
echo "ota: times: $times"
mkdir -p "$(dirname "$timings")" && echo "$(date '+%F %T') $version ($build) $sha: $times" >>"$timings"
# For the watcher: one line, space separated.
echo "ota-built: $version $build $sha $selected $sum $dest"
