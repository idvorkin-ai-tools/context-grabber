#!/usr/bin/env bash
# `just testflight`: the current commit to TestFlight, beside the cable install (#1012, stories 1011-1013,
# docs/superpowers/specs/2026-11-20-testflight-lane-design.md; docs/TESTING.md "TestFlight" has the one-time setup).
# Archives Grabber Native in Release with the build stamps, exports it signed for App Store distribution (the app, the
# widgets, the share extension), then uploads it with an App Store Connect API key.
#
# Usage: testflight.sh [--export-only] [--allow-dirty] [--build-number <n>] [--dry-run]
#   --export-only   archive and export only: needs no key, uploads nothing (story 1013)
#   --allow-dirty   ship a checkout with uncommitted changes (the build's BugKit commit then says -dirty)
#   --build-number  instead of the commit count (also BUILD_NUMBER=<n>)
#   --dry-run       check the key and the checkout, print the plan, build nothing
#
# The key: ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the AuthKey_<id>.p8 file, kept outside the repository) from
# the environment, else KEY=value lines in the gitignored scripts/native/testflight.local. The repository is public:
# none of the three is ever committed.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export_only=0 allow_dirty=0 dry_run=0
build_number=${BUILD_NUMBER:-}
while [ $# -gt 0 ]; do
  case "$1" in
    --export-only) export_only=1 ;;
    --allow-dirty) allow_dirty=1 ;;
    --dry-run) dry_run=1 ;;
    --build-number)
      build_number=${2:-}
      shift
      ;;
    -h | --help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "testflight: unknown argument $1 (--help)" >&2
      exit 64
      ;;
  esac
  shift
done

# --- The key: the environment first, then the ignored local file (values only, never evaluated) ---
local_file=${TESTFLIGHT_LOCAL:-scripts/native/testflight.local}
if [ -f "$local_file" ]; then
  while IFS='=' read -r k v || [ -n "$k" ]; do
    v=${v%$'\r'}
    v=${v#\"} v=${v%\"}
    case "$k" in
      ASC_KEY_ID | ASC_ISSUER_ID | ASC_KEY_PATH) [ -n "${!k:-}" ] || printf -v "$k" '%s' "$v" ;;
    esac
  done <"$local_file"
fi
ASC_KEY_PATH=${ASC_KEY_PATH:-}
ASC_KEY_PATH=${ASC_KEY_PATH/#\~/$HOME}
if [ "$export_only" = 0 ]; then
  missing=()
  [ -n "${ASC_KEY_ID:-}" ] || missing+=(ASC_KEY_ID)
  [ -n "${ASC_ISSUER_ID:-}" ] || missing+=(ASC_ISSUER_ID)
  [ -n "$ASC_KEY_PATH" ] || missing+=(ASC_KEY_PATH)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "testflight: no App Store Connect key: ${missing[*]} not set, in the environment or in $local_file" >&2
    echo "  (one KEY=value per line; docs/TESTING.md \"TestFlight\" says how to make the key). --export-only needs none." >&2
    exit 78
  fi
  if [ ! -r "$ASC_KEY_PATH" ]; then
    echo "testflight: ASC_KEY_PATH names no readable file (the .p8 App Store Connect gave you, outside the repository)" >&2
    exit 78
  fi
  case "$(cd "$(dirname "$ASC_KEY_PATH")" 2>/dev/null && pwd -P)/" in
    "$(pwd -P)"/*)
      echo "testflight: the key file is inside the repository; move it out (the repository is public)" >&2
      exit 78
      ;;
  esac
fi

# --- The checkout: a TestFlight build is a commit that exists ---
if [ "$allow_dirty" = 0 ]; then
  # Tracked changes anywhere, and untracked files where the build would pick them up.
  dirty=$( (git status --porcelain --untracked-files=no; git status --porcelain -- native assets scripts/native | grep '^??') | sort -u)
  if [ -n "$dirty" ]; then
    echo "testflight: uncommitted changes; commit them or pass --allow-dirty:" >&2
    echo "$dirty" | sed 's/^/  /' >&2
    exit 65
  fi
fi
if [ "$(git rev-parse --is-shallow-repository)" = true ] && [ -z "$build_number" ]; then
  echo "testflight: a shallow clone can't count its commits; fetch the history or pass --build-number" >&2
  exit 65
fi
sha=$(git rev-parse --short HEAD)
branch=$(git branch --show-current)
described=$(git describe --always --dirty --exclude='*')
build_number=${build_number:-$(git rev-list --count HEAD)}
case "$build_number" in
  '' | *[!0-9.]*)
    echo "testflight: build number '$build_number' is not a number" >&2
    exit 64
    ;;
esac
version=$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' native/project.yml | head -1)

stamp="GrabberNative-$version-$build_number-$sha"
archive=native/Build/Archives/$stamp.xcarchive
export_dir=native/Build/Export/$stamp
echo "testflight: $version ($build_number) from $sha on ${branch:-a detached HEAD}$([ "$export_only" = 1 ] && echo ', export only')"
if [ "$dry_run" = 1 ]; then
  echo "  archive: $archive"
  echo "  export:  $export_dir"
  [ "$export_only" = 1 ] || echo "  upload:  with the App Store Connect key (found)"
  exit 0
fi

# --- Archive and export, under the Mac's one signing lock and BugKit's screen-lock guard, as the cable build ---
guard=native/Build/SourcePackages/checkouts/bug-kit/scripts/signing-guard.sh
lock=$HOME/tmp/agent/locks/xcode-signing.lock
mkdir -p "${lock%/*}" native/Build/Archives "$export_dir"
xcodebuild -resolvePackageDependencies -project native/GrabberNative.xcodeproj -scheme GrabberNative \
  -derivedDataPath native/Build -quiet || exit 1
[ -x "$guard" ] || {
  echo "testflight: no BugKit signing guard at $guard (BugKit 0.3.3 or later)" >&2
  exit 69
}
rm -rf "$archive"
scripts/native/xcodebuild-log.sh testflight-archive "ARCHIVE SUCCEEDED" lockf "$lock" "$guard" xcodebuild \
  -project native/GrabberNative.xcodeproj -scheme GrabberNative -configuration Release \
  -destination generic/platform=iOS -derivedDataPath native/Build -archivePath "$archive" \
  -allowProvisioningUpdates \
  GIT_SHA="$sha" GIT_BRANCH="$branch" BUGKIT_COMMIT="$described" CURRENT_PROJECT_VERSION="$build_number" \
  archive || exit

options=$export_dir/ExportOptions.plist
cat >"$options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>export</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>$(sed -n 's/^ *DEVELOPMENT_TEAM: *//p' native/project.yml | head -1)</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
scripts/native/xcodebuild-log.sh testflight-export "EXPORT SUCCEEDED" lockf "$lock" "$guard" xcodebuild \
  -exportArchive -archivePath "$archive" -exportPath "$export_dir" -exportOptionsPlist "$options" \
  -allowProvisioningUpdates || exit
ipa=$(ls "$export_dir"/*.ipa 2>/dev/null | head -1)
[ -n "$ipa" ] || {
  echo "testflight: the export left no .ipa in $export_dir" >&2
  exit 1
}
# What the package says it is, read back rather than assumed.
plist=$(mktemp -d)/Info.plist
unzip -p "$ipa" 'Payload/GrabberNative.app/Info.plist' >"$plist"
shown="$(plutil -extract CFBundleShortVersionString raw "$plist") ($(plutil -extract CFBundleVersion raw "$plist")) from $(plutil -extract GitSha raw "$plist")"
echo "testflight: signed for App Store distribution: $ipa"
echo "  $shown"
if [ "$export_only" = 1 ]; then
  echo "testflight: export only, nothing uploaded"
  exit 0
fi

# --- Upload. Apple's processing takes 5-30 minutes after this before TestFlight offers the build. ---
auth=(--api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH")
xcrun altool --upload-package "$ipa" "${auth[@]}" || {
  echo "testflight: the upload failed; the package is still at $ipa (docs/TESTING.md \"TestFlight\": the app record, the key's role)" >&2
  exit 1
}
echo "testflight: uploaded $shown; TestFlight offers it once Apple has processed it (5-30 minutes)"
# #1038: the upload in the deploys ledger, apart from a device install; once TestFlight offers the build, say so with
# scripts/native/record-deploy.sh testflight <sha> testflight_available.
"$(dirname "$0")/record-deploy.sh" testflight "$(git rev-parse HEAD)" testflight_upload || true
