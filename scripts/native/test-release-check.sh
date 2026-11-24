#!/usr/bin/env bash
# Host test for scripts/native/release-check.sh (story 1519, bead context-grabber-6ocd): on a throwaway repository with
# a fake build command, a branch that leaves native/ContextCore alone skips the Release build, one that touches it runs
# it, a failing build fails the check with a FAIL line and exit 1, and RELEASE_CHECK=1 runs it even when nothing changed.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-release-check.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

git init -q -b main "$tmp/origin.git" --bare
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
cd "$tmp/repo" || exit 1
git config user.email t@t && git config user.name t
mkdir -p native/ContextCore docs
echo a >native/ContextCore/A.swift && echo d >docs/x.md
git add -A && git commit -qm base && git push -q origin main
git checkout -qb docs-only && echo d2 >>docs/x.md && git commit -qam docs
git checkout -qb core main && echo b >>native/ContextCore/A.swift && git commit -qam core

# check <name> <branch> <build exit> <want exit> <want line regex> [env…]
check() {
  local name=$1 branch=$2 build=$3 want=$4 line=$5 out status
  shift 5
  git checkout -q "$branch"
  out=$(env "$@" RELEASE_CHECK_BUILD="echo built; exit $build" "$here/release-check.sh" 2>&1)
  status=$?
  if [ "$status" -eq "$want" ] && grep -qE "$line" <<<"$out"; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $status, want $want)"
    sed 's/^/     /' <<<"$out"
    fail=1
  fi
}

check "a branch that leaves ContextCore alone skips the build" docs-only 1 0 '^ok   release-check: .*skipped'
check "a branch that touches ContextCore builds it" core 0 0 '^ok   release-check: .*Release build passes'
check "a failing Release build fails the check" core 1 1 '^FAIL release-check: '
check "RELEASE_CHECK=1 builds even when nothing changed" docs-only 0 0 '^ok   release-check: .*Release build passes' RELEASE_CHECK=1
exit $fail
