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
# Environment: OTA_HOST (developer@c-5004) and OTA_DIR (gits/igor2/cockpit-data/builds), where the package goes;
# IPAD, the iPad's UDID, else the gitignored scripts/native/ipad-udid.local (never printed whole); OTA_LOCK, the
# one-ota-at-a-time lock; OTA_TIMINGS, the local log of each run's step times.
# Exits: 0 built and copied; 64 usage; 65 main can't be checked out or pulled; 66 no such .ipa; 75 another ota is
# running; 78 a person must act (no iPad id, the iPad not in the profile, Xcode's account lost); 80 the Mac stayed
# locked (BugKit's guard); a failed build's own code otherwise.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
args=("$@")

dry_run=0 check_ipa=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --check-ipa)
      check_ipa=${2:-}
      [ -n "$check_ipa" ] || {
        echo "ota: --check-ipa needs a path" >&2
        exit 64
      }
      shift
      ;;
    -h | --help)
      sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
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
lock=${OTA_LOCK:-$HOME/tmp/agent/locks/ota.lock}
timings=${OTA_TIMINGS:-$HOME/tmp/agent/notes/ota-timings.log}

# The iPad's id, as scripts/native/devices.sh reads it; shown only as its first and last four characters.
ipad=${IPAD:-}
[ -z "$ipad" ] && [ -s scripts/native/ipad-udid.local ] && ipad=$(tr -d '[:space:]' <scripts/native/ipad-udid.local)
if [ -z "$ipad" ]; then
  echo "ota: no iPad id: set IPAD=<udid> or write it to scripts/native/ipad-udid.local (gitignored; docs/DEPLOYING.md \"Adding a device\")" >&2
  exit 78
fi
shown_ipad="${ipad:0:4}…${ipad: -4}"

# Every embedded profile in the package (the app, the widgets, the share extension) must list the iPad.
check_profiles() { # <ipa>
  local ipa=$1 tmp p name expires left missing=0 found=0 want
  want=$(tr 'a-z' 'A-Z' <<<"$ipad")
  tmp=$(mktemp -d)
  unzip -q -o "$ipa" 'Payload/*embedded.mobileprovision' -d "$tmp" 2>/dev/null
  while IFS= read -r p; do
    found=1
    security cms -D -i "$p" >"$tmp/profile.plist" 2>/dev/null || {
      echo "ota: can't read the profile ${p#"$tmp"/}" >&2
      missing=1
      continue
    }
    name=$(plutil -extract Name raw "$tmp/profile.plist" 2>/dev/null)
    if ! plutil -extract ProvisionedDevices json -o - "$tmp/profile.plist" 2>/dev/null | tr 'a-z' 'A-Z' | grep -qF "\"$want\""; then
      echo "ota: the profile \"$name\" doesn't list the iPad ($shown_ipad): register it and build again (docs/DEPLOYING.md \"Adding a device\")" >&2
      missing=1
      continue
    fi
    expires=$(plutil -extract ExpirationDate raw "$tmp/profile.plist" 2>/dev/null)
    left=$((($(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$expires" +%s 2>/dev/null || echo 0) - $(date +%s)) / 86400))
    [ "$left" -lt 30 ] && echo "ota: warning: the profile \"$name\" expires $expires, in $left days (docs/DEPLOYING.md \"Renewing the profile\")" >&2
    echo "ota: profile \"$name\" lists the iPad ($shown_ipad), expires $expires"
  done < <(find "$tmp/Payload" -name embedded.mobileprovision 2>/dev/null | sort)
  rm -rf "$tmp"
  [ "$found" = 1 ] || {
    echo "ota: $ipa has no embedded profile: not a device build" >&2
    return 78
  }
  [ "$missing" = 0 ] || return 78
}

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
  mkdir -p "$(dirname "$lock")"
  OTA_LOCKED=1 lockf -k -t 0 "$lock" "$0" ${args[@]+"${args[@]}"}
  rc=$?
  [ "$rc" = 75 ] && echo "ota: another ota is running (the lock $lock)" >&2
  exit "$rc"
fi

t0=$(date +%s)
if [ "$(git branch --show-current)" != main ]; then
  git checkout -q main || {
    echo "ota: can't check out main here (is it checked out in another worktree?)" >&2
    exit 65
  }
fi
git pull -q --ff-only || {
  echo "ota: main can't be pulled fast-forward" >&2
  exit 65
}
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
[ -d "$archive" ] || {
  echo "ota: testflight left no archive at $archive" >&2
  exit 1
}

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
plist=$(mktemp)
unzip -p "$ipa" 'Payload/GrabberNative.app/Info.plist' >"$plist"
version=$(plutil -extract CFBundleShortVersionString raw "$plist")
build=$(plutil -extract CFBundleVersion raw "$plist")
sha=$(plutil -extract GitSha raw "$plist")
rm -f "$plist"
full=$(git rev-parse "$sha" 2>/dev/null || echo "$sha")
sum=$(shasum -a 256 "$ipa" | cut -c1-16)
dest="$host:$dir/grabber-$sha.ipa"
t3=$(date +%s)
scp -q -o BatchMode=yes -o ConnectTimeout=15 "$ipa" "$dest" || {
  rc=$?
  echo "ota: the copy to $dest failed; the package is at $ipa" >&2
  exit "$rc"
}
t4=$(date +%s)
times="archive and App Store export $((t1 - t0)) s, development export $((t2 - t1)) s, check $((t3 - t2)) s, copy $((t4 - t3)) s, total $((t4 - t0)) s"
echo "ota: $version ($build) $sha -> $dest (sha256 $sum)"
echo "ota: times: $times"
mkdir -p "$(dirname "$timings")" && echo "$(date '+%F %T') $version ($build) $sha: $times" >>"$timings"
# For the watcher: one line, space separated.
echo "ota-built: $version $build $sha $full $sum $dest"
