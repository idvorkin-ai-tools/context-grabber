#!/usr/bin/env bash
# Stories 1027-1029 (bead context-grabber-omes): `just ota`'s arguments, its dry run and the iPad id it never prints
# whole; `just ota-watch`'s batch rule, its post and what it remembers, against a throwaway history with merges at
# chosen times and fake ota and larry commands. Nothing is built, signed, copied or posted.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
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

# --- A main with an origin; merges at chosen commit times (T0 is a fixed clock) ---
T0=1795000000
git init -q --bare -b main "$tmp/origin.git"
repo=$tmp/repo
git clone -q "$tmp/origin.git" "$repo" 2>/dev/null
mkdir -p "$repo/scripts/native" "$repo/native"
cp -f "$here/ota.sh" "$here/ota-watch.sh" "$here/testflight.sh" "$repo/scripts/native/"
printf 'settings:\n  base:\n    DEVELOPMENT_TEAM: TEAM\n    MARKETING_VERSION: "2.0.0"\n' >"$repo/native/project.yml"
merge() { # <pr> <title> <commit time>
  (
    cd "$repo" || exit 1
    g checkout -q -b "pr$1"
    g commit -q --allow-empty -m "work for $1"
    g checkout -q main
    GIT_COMMITTER_DATE="@$3 +0000" g merge -q --no-ff --no-edit "pr$1" -m "Merge pull request #$1 from someone/pr$1" -m "$2"
    g push -q origin main
  )
}
(cd "$repo" && g checkout -q -b main 2>/dev/null; g add -A && GIT_COMMITTER_DATE="@$((T0 - 9000)) +0000" g commit -qm base && g push -q -u origin main) || exit 1
base=$(git -C "$repo" rev-parse HEAD)

# --- ota.sh: arguments, the iPad id, the dry run ---
fake_id=00008888-0123456789ABCDEF
env -u IPAD "$repo/scripts/native/ota.sh" --bogus >"$out" 2>&1
expect $? "ota: an unknown argument" 64 "unknown argument --bogus"
env -u IPAD "$repo/scripts/native/ota.sh" --help >"$out" 2>&1
expect $? "ota: --help" 0 "--check-ipa"
env -u IPAD "$repo/scripts/native/ota.sh" --dry-run >"$out" 2>&1
expect $? "ota: no iPad id stops it, saying where the id goes" 78 "scripts/native/ipad-udid.local"
echo "$fake_id" >"$repo/scripts/native/ipad-udid.local"
env -u IPAD OTA_HOST=me@box OTA_DIR=builds/here "$repo/scripts/native/ota.sh" --dry-run >"$out" 2>&1
expect $? "ota: the dry run names the destination, overridable" 0 "copy:    me@box:builds/here/grabber-$(git -C "$repo" rev-parse --short HEAD).ipa"
expect 0 "ota: the dry run masks the iPad id from the local file" 0 "the iPad (0000…CDEF)"
absent "ota: the full iPad id is never printed" "$fake_id"
IPAD=$fake_id "$repo/scripts/native/ota.sh" --check-ipa "$tmp/none.ipa" >"$out" 2>&1
expect $? "ota: --check-ipa of no file" 66 "no such .ipa"
IPAD=$fake_id "$repo/scripts/native/ota.sh" --check-ipa >"$out" 2>&1
expect $? "ota: --check-ipa needs a path" 64 "needs a path"
rm -f "$repo/scripts/native/ipad-udid.local"

# --- ota-watch.sh: the fakes ---
cat >"$tmp/ota" <<'EOF'
#!/usr/bin/env bash
# The fake ota: pulls as the real one does, then says what it built, or fails with FAKE_OTA_EXIT.
echo "ota: run" >>"$FAKE_LOG"
[ "${FAKE_OTA_EXIT:-0}" = 0 ] || { echo "ota: the fake failed"; exit "$FAKE_OTA_EXIT"; }
git pull -q --ff-only
full=$(git rev-parse HEAD)
echo "ota-built: 2.0.0 $(git rev-list --count HEAD) ${full:0:8} $full 0123456789abcdef me@box:builds/grabber-${full:0:8}.ipa"
EOF
cat >"$tmp/larry" <<'EOF'
#!/usr/bin/env bash
echo "larry $* :: $(cat)" >>"$FAKE_LOG"
EOF
chmod +x "$tmp/ota" "$tmp/larry"
log=$tmp/calls
last=$tmp/last-sha
watch() { # <now> [args]: one poll at that clock
  local at=$1
  shift
  : >"$log"
  (cd "$repo" && OTA_NOW=$at OTA_LAST_SHA_FILE=$last OTA_CMD=$tmp/ota LARRY=$tmp/larry FAKE_LOG=$log \
    OTA_WATCH_LOCK=$tmp/watch.lock OTA_QUIET=600 "$repo/scripts/native/ota-watch.sh" --once "$@") >"$out" 2>&1
}

"$repo/scripts/native/ota-watch.sh" --quiet x >"$out" 2>&1
expect $? "watch: --quiet needs seconds" 64 "needs a number of seconds"
watch "$T0"
expect $? "watch: the first run starts from main and builds nothing" 0 "starting from main at ${base:0:8}"
[ "$(cat "$last")" = "$base" ] && [ ! -s "$log" ] && ok "watch: the first run remembers main, runs no ota" || bad "watch: the first run remembers main, runs no ota"
watch "$T0"
expect $? "watch: nothing new" 0 "nothing new since"

merge 101 "feat: the first change" $((T0 - 900))
merge 102 "fix: the second change" $((T0 - 300))
watch "$T0"
expect $? "watch: a merge 5 minutes old keeps the batch open" 0 "building 300 s after the last merge"
[ ! -s "$log" ] && ok "watch: no ota while the batch is open" || bad "watch: no ota while the batch is open"
watch $((T0 + 300)) --dry-run
expect $? "watch: the dry run names the PRs, newest first" 0 "with: #102 fix: the second change; #101 feat: the first change"
[ ! -s "$log" ] && [ "$(cat "$last")" = "$base" ] && ok "watch: the dry run runs, posts and remembers nothing" || bad "watch: the dry run runs, posts and remembers nothing"

FAKE_OTA_EXIT=75 watch $((T0 + 300))
expect $? "watch: ota busy or the Mac locked: tried again later" 0 "trying again at the next poll"
grep -q '^larry' "$log" && bad "watch: nothing posted when ota could not start" || ok "watch: nothing posted when ota could not start"
FAKE_OTA_EXIT=1 watch $((T0 + 300))
expect $? "watch: a failed build is said in the thread" 0 ""
grep -qF -- "--id cc-ota-fail-" "$log" && grep -qF "failed (exit 1)" "$log" && ok "watch: the failure is posted once, with its id" || bad "watch: the failure is posted once, with its id"
[ "$(cat "$last")" = "$base" ] && ok "watch: a failure leaves the last build as it was" || bad "watch: a failure leaves the last build as it was"
FAKE_OTA_EXIT=78 watch $((T0 + 300))
expect $? "watch: a build that needs a person stops the watcher" 78 "stopping"
grep -qF "a person must act" "$log" && ok "watch: and says so in the thread" || bad "watch: and says so in the thread"

watch $((T0 + 300))
expect $? "watch: ten quiet minutes end the batch: it builds and posts" 0 "and posted it"
head=$(git -C "$tmp/origin.git" rev-parse main)
grep -qF -- "--thread igor2-88g.1620 --id cc-ota-${head:0:8} :: New build on /builds: 2.0.0 (" "$log" &&
  grep -qF "${head:0:8}, with: #102 fix: the second change; #101 feat: the first change" "$log" &&
  ok "watch: the post: version, build, commit and the PRs" || {
  sed 's/^/     /' "$log"
  bad "watch: the post: version, build, commit and the PRs"
}
[ "$(cat "$last")" = "$head" ] && ok "watch: it remembers the commit built" || bad "watch: it remembers the commit built"
watch $((T0 + 900))
expect $? "watch: restarted after the build, nothing is rebuilt" 0 "nothing new since ${head:0:8}"

merge 103 "feat: the next batch" $((T0 + 1000))
watch $((T0 + 2000))
expect $? "watch: a batch that ended while no watcher ran builds on the first poll" 0 "and posted it"
grep -qF "with: #103 feat: the next batch" "$log" && ! grep -qF "#102" "$log" && ok "watch: only the PRs since the last build" || {
  sed 's/^/     /' "$log"
  bad "watch: only the PRs since the last build"
}

[ "$fails" = 0 ] || exit 1
