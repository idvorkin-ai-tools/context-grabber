#!/usr/bin/env bash
# Builds main over the air after each merge batch (bead context-grabber-omes, story 1029; docs/DEPLOYING.md).
# Polls origin/main every minute and waits for ten minutes without a merge before building. Posts the build and
# its pull requests to Igor's Cockpit thread. Runs in the foreground.
#
# Usage: ota-watch.sh [--help]
set -uo pipefail
case "${1:-}" in
  -h | --help)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  '')
    [ $# -eq 0 ] || { echo "ota-watch: empty argument (--help)" >&2; exit 64; }
    ;;
  *)
    echo "ota-watch: unknown argument $1 (--help)" >&2
    exit 64
    ;;
esac
repo=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
cd "$repo" || exit 1

last_file=$HOME/tmp/agent/ota-last-sha
lock=$HOME/tmp/agent/locks/ota-watch.lock
ota_cmd=$repo/scripts/native/ota.sh
larry=larry
test_dir=${OTA_WATCH_TEST_DIR:-}
if [ -n "$test_dir" ]; then
  last_file=$test_dir/last-sha
  lock=$test_dir/watch.lock
  ota_cmd=$test_dir/ota
  larry=$test_dir/larry
fi

if [ -z "${OTA_WATCH_LOCKED:-}" ]; then
  mkdir -p "$(dirname "$lock")" || exit
  OTA_WATCH_LOCKED=1 lockf -k -t 0 "$lock" "$repo/scripts/native/ota-watch.sh"
  rc=$?
  [ "$rc" = 75 ] && echo "ota-watch: another watcher is running (the lock $lock)" >&2
  exit "$rc"
fi

now() {
  if [ -n "$test_dir" ]; then echo "$OTA_NOW"; else date +%s; fi
}
say() { echo "ota-watch $(date '+%H:%M:%S'): $*"; }

# "#1231 feat(native): search Larry's asks …; #1230 …": each merge's PR number and title (a GitHub merge commit's
# subject names the PR; the first line of its body is the PR's title), newest first.
titles() { # <from> <to>
  local h subject title n out=""
  for h in $(git log --merges --first-parent --format=%H "$1..$2"); do
    subject=$(git log -1 --format=%s "$h")
    title=$(git log -1 --format=%b "$h" | sed -n '/./{p;q;}')
    n=$(sed -n 's/^Merge pull request \(#[0-9][0-9]*\).*/\1/p' <<<"$subject")
    [ -n "$title" ] || title=$subject
    out="$out${out:+; }${n:+$n }$title"
  done
  echo "$out"
}

save_checkpoint() {
  printf '%s\n' "$@" >"$last_file.tmp" && mv -f "$last_file.tmp" "$last_file"
}

announce() { # <full commit> <post id> <message>
  if printf '%s\n' "$3" | "$larry" post --thread igor2-88g.1620 --id "$2" >/dev/null; then
    save_checkpoint "$1" || return
    say "posted the build of ${1:0:8}"
  else
    say "the post $2 failed; trying again at the next poll"
  fi
}

poll() {
  local head last="" post_id="" message="" newest remaining
  if [ -s "$last_file" ]; then
    {
      IFS= read -r last
      IFS= read -r post_id
      IFS= read -r message
    } <"$last_file"
    if [ -n "$post_id" ]; then
      announce "$last" "$post_id" "$message"
      return
    fi
  fi

  git fetch -q origin +refs/heads/main:refs/remotes/origin/main 2>/dev/null || {
    say "can't fetch origin/main; trying again at the next poll"
    return 0
  }
  head=$(git rev-parse refs/remotes/origin/main) || return
  if [ -z "$last" ]; then
    save_checkpoint "$head" || return
    say "starting from main at ${head:0:8}; the next merge batch builds"
    return 0
  fi

  newest=$(git log --merges --first-parent --format=%ct -1 "$last..$head") || return
  if [ -z "$newest" ]; then
    [ -z "$test_dir" ] || say "nothing new since ${last:0:8}"
    return 0
  fi
  remaining=$((600 - ($(now) - newest)))
  if [ "$remaining" -gt 0 ]; then
    say "a batch is open: $remaining s remaining before the build, if no other merge comes"
    return 0
  fi
  build "$last" "$head"
}

build() { # <last> <head>
  local last=$1 head=$2 out rc line version num sha full post_id message
  say "the batch is done; building main (${head:0:8})"
  out=$(mktemp) || return
  OTA_EXPECTED_SHA=$head "$ota_cmd" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  line=$(grep '^ota-built: ' "$out" | tail -1)
  rm -f "$out"
  case "$rc" in
    0) ;;
    75 | 80)
      say "ota deferred (exit $rc); trying again at the next poll"
      return 0
      ;;
    *)
      say "ota failed (exit $rc); stopping"
      return "$rc"
      ;;
  esac
  read -r _ version num sha full _ <<<"$line"
  if [ "$full" != "$head" ]; then
    say "ota did not report a build of $head; stopping"
    return 1
  fi
  post_id=cc-ota-$sha
  message="New build on /builds: $version ($num) $sha, with: $(titles "$last" "$head")"
  save_checkpoint "$head" "$post_id" "$message" || return
  announce "$head" "$post_id" "$message"
}

if [ -n "$test_dir" ]; then
  poll
  exit
fi
say "watching origin/main every 60 s; a batch ends 600 s after its last merge"
while :; do
  poll || exit $?
  sleep 60
done
