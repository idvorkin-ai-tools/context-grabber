#!/usr/bin/env bash
# Stories 1027-1029: recipe arguments, profile validation, publication and the watcher against a local origin.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d) || exit
trap 'rm -rf "$tmp"' EXIT
fails=0
ok() { echo "ok   $1"; }
bad() {
  echo "FAIL $1"
  fails=$((fails + 1))
}
out=$tmp/out
expect() { # <exit> <name> <exit wanted> <text wanted>
  local code=$1 name=$2 want=$3 text=$4
  if [ "$code" = "$want" ] && grep -qF -- "$text" "$out"; then ok "$name"; else
    echo "     exit $code, wanted $want and: $text"
    sed 's/^/     /' "$out"
    bad "$name"
  fi
}
absent() { # <name> <text that must not appear>
  if grep -qF -- "$2" "$out"; then
    sed 's/^/     /' "$out"
    bad "$1"
  else ok "$1"; fi
}
g() { git -c user.name=t -c user.email=t@t "$@"; }

T0=1795000000
origin=$tmp/origin.git
producer=$tmp/producer
repo=$tmp/repo
git init -q --bare -b main "$origin" || exit
git clone -q "$origin" "$producer" 2>/dev/null || exit
mkdir -p "$producer/scripts/native" "$producer/native" "$tmp/bin"
cp -f "$here/ota.sh" "$here/ota-watch.sh" "$here/testflight.sh" "$producer/scripts/native/"
cp -f "$here/../../justfile" "$producer/"
printf 'native/Build/\nscripts/native/ipad-udid.local\n' >"$producer/.gitignore"
printf 'settings:\n  base:\n    DEVELOPMENT_TEAM: TEAM\n    MARKETING_VERSION: "2.0.0"\n' >"$producer/native/project.yml"
cat >"$producer/scripts/native/xcodebuild-log.sh" <<'STUB'
#!/usr/bin/env bash
while [ $# -gt 1 ]; do
  if [ "$1" = -exportPath ]; then
    cp -f "$FAKE_IPA" "$2/GrabberNative.ipa"
    exit
  fi
  shift
done
exit 1
STUB
chmod +x "$producer/scripts/native/xcodebuild-log.sh"
merge() { # <pr> <title> <commit time>
  (
    cd "$producer" &&
    g checkout -q -b "pr$1" &&
    g commit -q --allow-empty -m "work for $1" &&
    g checkout -q main &&
    GIT_COMMITTER_DATE="@$3 +0000" g merge -q --no-ff --no-edit "pr$1" -m "Merge pull request #$1 from someone/pr$1" -m "$2"
  )
}
publish_main() { g -C "$producer" push -q origin main; }
(cd "$producer" && g add -A && GIT_COMMITTER_DATE="@$((T0 - 9000)) +0000" g commit -qm base) &&
  publish_main && git clone -q "$origin" "$repo" || exit 1
base=$(git -C "$repo" rev-parse HEAD)
short=$(git -C "$repo" rev-parse --short HEAD)

fake_id=00008888-0123456789ABCDEF
ota() { (cd "$repo" && just ota "$@") >"$out" 2>&1; }
ota --bogus
expect $? "ota: an unknown argument" 64 "unknown argument --bogus"
ota --help
expect $? "ota: --help" 0 "--check-ipa"
IPAD=$fake_id ota --dry-run
expect $? "ota: the id must come from the local file" 78 "scripts/native/ipad-udid.local"
echo "$fake_id" >"$repo/scripts/native/ipad-udid.local"
IPAD=STALE OTA_HOST=me@box OTA_DIR=builds/here ota --dry-run
expect $? "ota: the dry run names the chosen destination" 0 "copy:    me@box:builds/here/grabber-$short.ipa"
expect 0 "ota: the dry run masks the iPad id from the local file" 0 "the iPad (0000…CDEF)"
absent "ota: the full iPad id stays private" "$fake_id"
ota --check-ipa "$tmp/iPad Builds/none.ipa"
expect $? "ota: the recipe forwards a path with spaces" 66 "$tmp/iPad Builds/none.ipa"
ota --check-ipa
expect $? "ota: --check-ipa needs a path" 64 "needs a path"

# The IPA has a readable app profile and a widget profile. A CRC failure in the widget must reject the whole IPA.
package=$tmp/package
app=Payload/GrabberNative.app
widget=$app/PlugIns/Widgets.appex
mkdir -p "$package/$widget"
for bundle in "$app" "$widget"; do
  cat >"$package/$bundle/embedded.mobileprovision" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Name</key><string>${bundle##*/}</string>
<key>ProvisionedDevices</key><array><string>$fake_id</string></array>
<key>ExpirationDate</key><date>2027-11-20T00:00:00Z</date>
</dict></plist>
PLIST
done
cat >"$package/$app/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleShortVersionString</key><string>2.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>GitSha</key><string>$short</string>
</dict></plist>
PLIST
cat >"$tmp/bin/security" <<'STUB'
#!/usr/bin/env bash
cat "$4"
STUB
chmod +x "$tmp/bin/security"
ipa=$tmp/complete.ipa
corrupt=$tmp/corrupt.ipa
(cd "$package" && zip -q -0 "$ipa" "$app/Info.plist" "$app/embedded.mobileprovision" "$widget/embedded.mobileprovision") || exit
python3 - "$ipa" "$corrupt" "$widget/embedded.mobileprovision" <<'PY' || exit
import struct
import sys
import zipfile
from pathlib import Path

source, dest, entry = sys.argv[1:]
with zipfile.ZipFile(source) as archive:
    offset = archive.getinfo(entry).header_offset
data = bytearray(Path(source).read_bytes())
name_length, extra_length = struct.unpack_from("<HH", data, offset + 26)
data[offset + 30 + name_length + extra_length] ^= 1
Path(dest).write_bytes(data)
PY
PATH="$tmp/bin:$PATH" ota --check-ipa "$ipa"
expect $? "ota: a complete IPA lists the iPad in both profiles" 0 'profile "Widgets.appex" lists the iPad'
absent "ota: the profile check masks the iPad id" "$fake_id"
PATH="$tmp/bin:$PATH" ota --check-ipa "$corrupt"
expect $? "ota: one failed extraction rejects a partially readable IPA" 78 "can't extract and enumerate"

cat >"$tmp/bin/just" <<'STUB'
#!/usr/bin/env bash
[ "$*" = 'testflight --export-only' ]
STUB
cat >"$tmp/bin/mkdir" <<'STUB'
#!/usr/bin/env bash
[ "$*" != "-p $HOME/tmp/agent/notes" ] || exit 1
exec /bin/mkdir "$@"
STUB
cat >"$tmp/bin/scp" <<'STUB'
#!/usr/bin/env bash
dest=${@: -1}
dest=${dest#*:}
if [ "${FAIL_COPY:-0}" = 1 ]; then
  printf 'partial' >"$dest"
  exit 1
fi
cp -f "${@: -2:1}" "$dest"
STUB
cat >"$tmp/bin/ssh" <<'STUB'
#!/usr/bin/env bash
exec /bin/sh -c "${@: -1}"
STUB
chmod +x "$tmp/bin/"*
builds="$tmp/iPad's Builds"
mkdir -p "$builds"
published=$builds/grabber-$short.ipa
printf 'known good' >"$published"
run_ota() {
  PATH="$tmp/bin:$PATH" OTA_LOCKED=1 OTA_HOST=me@box OTA_DIR="$builds" FAKE_IPA="$1" \
    "$repo/scripts/native/ota.sh" >"$out" 2>&1
}
run_ota "$corrupt"
expect $? "ota: the shared profile check also blocks publication" 78 "can't extract and enumerate"
[ "$(cat "$published")" = "known good" ] && ok "ota: validation leaves the published build intact" ||
  bad "ota: validation leaves the published build intact"
FAIL_COPY=1 run_ota "$ipa"
expect $? "ota: an interrupted copy fails" 1 "the copy to"
[ "$(cat "$published")" = "known good" ] && ok "ota: interrupted copy leaves the published build intact" ||
  bad "ota: interrupted copy leaves the published build intact"
run_ota "$ipa"
expect $? "ota: a complete copy is published" 0 "ota-built: 2.0.0 1 $short $base"
cmp -s "$published" "$ipa" && ok "ota: the published bytes match the complete export" ||
  bad "ota: the published bytes match the complete export"

cat >"$tmp/ota" <<'STUB'
#!/usr/bin/env bash
echo "ota: run" >>"$FAKE_LOG"
if [ "${ADVANCE_MAIN:-0}" = 1 ]; then
  git -C "$PRODUCER" push -q origin main || exit
  exec "$PWD/scripts/native/ota.sh"
fi
[ "${FAKE_OTA_EXIT:-0}" = 0 ] || { echo "ota: local-only build error"; exit "$FAKE_OTA_EXIT"; }
full=$(git rev-parse refs/remotes/origin/main)
[ "$full" = "$OTA_EXPECTED_SHA" ] || exit 1
echo "ota-built: 2.0.0 $(git rev-list --count "$full") ${full:0:8} $full 0123456789abcdef me@box:builds/grabber-${full:0:8}.ipa"
STUB
cat >"$tmp/larry" <<'STUB'
#!/usr/bin/env bash
echo "larry $* :: $(cat)" >>"$FAKE_LOG"
exit "${FAKE_POST_EXIT:-0}"
STUB
chmod +x "$tmp/ota" "$tmp/larry"
log=$tmp/calls
last=$tmp/last-sha
watch() {
  local at=$1
  shift
  : >"$log"
  PATH="$tmp/bin:$PATH" OTA_LOCKED=1 OTA_WATCH_TEST_DIR=$tmp OTA_NOW=$at FAKE_LOG=$log PRODUCER=$producer \
    "$repo/scripts/native/ota-watch.sh" "$@" >"$out" 2>&1
}

for option in --once --dry-run --quiet --interval; do
  watch "$T0" "$option"
  expect $? "watch: rejects $option" 64 "unknown argument $option"
done
watch "$T0"
expect $? "watch: the first run starts from main" 0 "starting from main at ${base:0:8}"
[ "$(cat "$last")" = "$base" ] && [ ! -s "$log" ] && ok "watch: the first run remembers main without building" ||
  bad "watch: the first run remembers main without building"

merge 101 "feat: the first change" $((T0 - 900)) && merge 102 "fix: the second change" $((T0 - 300)) && publish_main || exit
watch "$T0"
expect $? "watch: a five-minute-old remote merge leaves five minutes to wait" 0 "300 s remaining"
[ ! -s "$log" ] && ok "watch: no build while the batch is open" || bad "watch: no build while the batch is open"

for code in 75 80; do
  FAKE_OTA_EXIT=$code watch $((T0 + 300))
  expect $? "watch: exit $code defers until the next poll" 0 "trying again at the next poll"
  [ "$(cat "$last")" = "$base" ] && ! grep -q '^larry' "$log" && ok "watch: exit $code leaves the checkpoint and thread alone" ||
    bad "watch: exit $code leaves the checkpoint and thread alone"
done
for code in 1 78; do
  FAKE_OTA_EXIT=$code watch $((T0 + 300))
  expect $? "watch: exit $code stops the watcher" "$code" "stopping"
  [ "$(cat "$last")" = "$base" ] && ! grep -q '^larry' "$log" && ok "watch: exit $code keeps diagnostics local" ||
    bad "watch: exit $code keeps diagnostics local"
done

merge 103 "feat: the merge racing OTA" $((T0 + 299)) || exit
ADVANCE_MAIN=1 watch $((T0 + 300))
expect $? "watch: real OTA defers when main advances after the poll" 0 "origin/main advanced since the watcher polled"
[ "$(cat "$last")" = "$base" ] && ! grep -q '^larry' "$log" && ok "watch: a quiet-window race neither posts nor advances" ||
  bad "watch: a quiet-window race neither posts nor advances"
watch $((T0 + 300))
expect $? "watch: the merge that raced OTA opens the quiet window again" 0 "599 s remaining"

head=$(git -C "$origin" rev-parse main)
FAKE_POST_EXIT=1 OTA_THREAD=wrong-thread watch $((T0 + 899))
expect $? "watch: ten quiet minutes end the batch, and a failed post is deferred" 0 "trying again at the next poll"
grep -qF -- "--thread igor2-88g.1620 --id cc-ota-${head:0:8} :: New build on /builds: 2.0.0 (7) ${head:0:8}, with: #103 feat: the merge racing OTA; #102 fix: the second change; #101 feat: the first change" "$log" &&
  ok "watch: the announcement names the checked build and all of its PRs" ||
  { cat "$log"; bad "watch: the announcement names the checked build and all of its PRs"; }
failed_post=$(sed -n '/^larry /p' "$log")
watch $((T0 + 960))
expect $? "watch: a fresh process retries the pending notice" 0 "posted the build"
[ "$(cat "$log")" = "$failed_post" ] && [ "$(cat "$last")" = "$head" ] &&
  ok "watch: the restart posts the same notice without rebuilding and records the commit" ||
  bad "watch: the restart posts the same notice without rebuilding and records the commit"
watch $((T0 + 1020))
expect $? "watch: a second restart finds nothing new" 0 "nothing new since ${head:0:8}"
[ ! -s "$log" ] && ok "watch: a delivered build stays quiet after restart" ||
  bad "watch: a delivered build stays quiet after restart"

merge 104 "feat: the next batch" $((T0 + 1100)) && publish_main || exit
watch $((T0 + 1800))
expect $? "watch: a batch that ended while no watcher ran builds on the first poll" 0 "posted the build"
grep -qF "with: #104 feat: the next batch" "$log" && ! grep -qF "#103" "$log" &&
  ok "watch: the next post includes only its own PRs" || bad "watch: the next post includes only its own PRs"
[ "$fails" = 0 ] || exit 1
