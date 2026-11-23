#!/usr/bin/env bash
# `just ota-watch`: builds main over the air after each merge batch (bead context-grabber-omes, story 1029; spec
# docs/superpowers/specs/2026-11-22-ota-builds-design.md; docs/DEPLOYING.md). Polls origin/main; once main has merges
# since the last build and then a quiet spell with no newer merge, it runs `just ota` and posts the build, with the pull
# requests it holds, to Igor's Cockpit thread. Runs in the foreground; whoever starts it keeps it running.
#
# Usage: ota-watch.sh [--once] [--dry-run] [--interval <s>] [--quiet <s>]
#   --once      one poll, then exit (the script check; a cron-style caller)
#   --dry-run   say what it would build and post; run nothing, post nothing, remember nothing
#   --interval  seconds between polls (OTA_INTERVAL, 60)
#   --quiet     seconds with no newer merge that end a batch (OTA_QUIET, 600)
#
# Environment: OTA_LAST_SHA_FILE (~/tmp/agent/ota-last-sha), the last commit built; OTA_THREAD (igor2-88g.1620);
# OTA_CMD (scripts/native/ota.sh); LARRY (larry); OTA_RETRY (3600), seconds before a failed build of the same main is
# tried again; OTA_NOW, the clock, for the script check.
# A build that needs a person (ota's 78: the Xcode account, the iPad not in the profile) posts why and stops (exit 78).
set -uo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
cd "$repo" || exit 1
args=("$@")

once=0 dry_run=0
interval=${OTA_INTERVAL:-60}
quiet=${OTA_QUIET:-600}
while [ $# -gt 0 ]; do
  case "$1" in
    --once) once=1 ;;
    --dry-run) dry_run=1 ;;
    --interval | --quiet)
      case "${2:-}" in '' | *[!0-9]*)
        echo "ota-watch: $1 needs a number of seconds" >&2
        exit 64
        ;;
      esac
      [ "$1" = --interval ] && interval=$2 || quiet=$2
      shift
      ;;
    -h | --help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ota-watch: unknown argument $1 (--help)" >&2
      exit 64
      ;;
  esac
  shift
done
last_file=${OTA_LAST_SHA_FILE:-$HOME/tmp/agent/ota-last-sha}
thread=${OTA_THREAD:-igor2-88g.1620}
ota_cmd=${OTA_CMD:-$repo/scripts/native/ota.sh}
larry=${LARRY:-larry}
retry=${OTA_RETRY:-3600}

# One watcher at a time (a dry run takes no lock).
if [ "$dry_run" = 0 ] && [ -z "${OTA_WATCH_LOCKED:-}" ]; then
  wlock=${OTA_WATCH_LOCK:-$HOME/tmp/agent/locks/ota-watch.lock}
  mkdir -p "$(dirname "$wlock")"
  OTA_WATCH_LOCKED=1 lockf -k -t 0 "$wlock" "$0" ${args[@]+"${args[@]}"}
  rc=$?
  [ "$rc" = 75 ] && echo "ota-watch: another watcher is running (the lock $wlock)" >&2
  exit "$rc"
fi

now() { echo "${OTA_NOW:-$(date +%s)}"; }
say() { echo "ota-watch $(date '+%H:%M:%S'): $*"; }

# The batch rule, from the last commit built, main's head and the clock: "none" (no merge since the last build),
# "wait <s>" (the newest merge is younger than the quiet spell) or "build". Judged on the merges' commit times, not
# on when this saw them, so a watcher started after a batch builds it on its first poll.
decide() { # <last> <head>
  local newest
  [ "$1" = "$2" ] && {
    echo none
    return
  }
  newest=$(git log --merges --first-parent --format=%ct -1 "$1..$2" 2>/dev/null)
  [ -n "$newest" ] || {
    echo none
    return
  }
  local age=$(($(now) - newest))
  if [ "$age" -lt "$quiet" ]; then echo "wait $((quiet - age))"; else echo build; fi
}

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

post() { # <id> <text>
  printf '%s\n' "$2" | "$larry" post --thread "$thread" --id "$1" >/dev/null || say "the post $1 failed: $2"
}

failed_head="" failed_at=0
poll() {
  git fetch -q origin main 2>/dev/null || {
    say "can't fetch origin/main; trying again at the next poll"
    return 0
  }
  local head last state
  head=$(git rev-parse origin/main) || return 0
  if [ ! -s "$last_file" ]; then
    if [ "$dry_run" = 1 ]; then
      say "no $last_file: would start from main at ${head:0:8} and build from the next batch"
    else
      mkdir -p "$(dirname "$last_file")" && echo "$head" >"$last_file"
      say "starting from main at ${head:0:8}; the next merge batch builds"
    fi
    return 0
  fi
  last=$(tr -d '[:space:]' <"$last_file")
  state=$(decide "$last" "$head")
  case "$state" in
    none) [ "$once" = 1 ] && say "nothing new since ${last:0:8}" ;;
    wait*) say "a batch is open: building ${state#wait } s after the last merge, if no other comes" ;;
    build)
      if [ "$head" = "$failed_head" ] && [ $(($(now) - failed_at)) -lt "$retry" ]; then
        [ "$once" = 1 ] && say "the build of ${head:0:8} failed; trying again after a new merge or $retry s"
        return 0
      fi
      if [ "$dry_run" = 1 ]; then
        say "would build main at ${head:0:8} and post: New build on /builds: <version> (<build>) ${head:0:8}, with: $(titles "$last" "$head")"
        return 0
      fi
      build "$last" "$head"
      return
      ;;
  esac
  return 0
}

build() { # <last> <head>
  local last=$1 head=$2 out rc line version num sha full
  say "the batch is done; building main (${head:0:8})"
  out=$(mktemp)
  "$ota_cmd" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  line=$(grep '^ota-built: ' "$out" | tail -1)
  case "$rc" in
    0) ;;
    75 | 80)
      say "ota could not start (another ota or signing build, or the Mac locked; exit $rc); trying again at the next poll"
      rm -f "$out"
      return 0
      ;;
    78)
      post "cc-ota-stop-${head:0:8}" "OTA build of ${head:0:8} stopped, a person must act: $(grep '^ota: ' "$out" | tail -1 | cut -c6-) (docs/DEPLOYING.md). The watcher has stopped."
      rm -f "$out"
      say "ota needs a person (exit 78); stopping"
      exit 78
      ;;
    *)
      post "cc-ota-fail-${head:0:8}" "OTA build of ${head:0:8} failed (exit $rc): $(grep -v '^ *$' "$out" | tail -1 | cut -c1-200). It is tried again after the next merge or in $((retry / 60)) minutes."
      failed_head=$head failed_at=$(now)
      rm -f "$out"
      return 0
      ;;
  esac
  rm -f "$out"
  [ -n "$line" ] || {
    say "ota succeeded but printed no ota-built line"
    failed_head=$head failed_at=$(now)
    return 0
  }
  read -r _ version num sha full _ <<<"$line"
  post "cc-ota-$sha" "New build on /builds: $version ($num) $sha, with: $(titles "$last" "$full")"
  echo "$full" >"$last_file"
  say "built $version ($num) $sha and posted it"
}

if [ "$once" = 1 ]; then
  poll
  exit
fi
say "watching origin/main every $interval s; a batch ends $quiet s after its last merge (last build: $(cut -c1-8 "$last_file" 2>/dev/null || echo none))"
while :; do
  poll
  sleep "$interval"
done
