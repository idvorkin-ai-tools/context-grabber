#!/usr/bin/env bash
# Stories 1012, 1013 (#1012): what `just testflight` refuses before it spends a build, and its plan, from the real
# script's --dry-run in a throwaway repository (nothing is built or signed).
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
repo=$tmp/repo
mkdir -p "$repo/scripts/native" "$repo/native" "$tmp/keys"
cp -f "$here/testflight.sh" "$repo/scripts/native/"
printf 'settings:\n  base:\n    DEVELOPMENT_TEAM: TEAM\n    MARKETING_VERSION: "2.0.0"\n' >"$repo/native/project.yml"
(
  cd "$repo" || exit 1
  git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm one && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
) || exit 1
echo key >"$tmp/keys/AuthKey_T.p8"
out=$tmp/out

# Runs the script's dry run: VAR=value words, then -- and the script's own arguments. The key's three are cleared first.
dry() {
  local vars=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    vars+=("$1")
    shift
  done
  [ $# -gt 0 ] && shift
  env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_PATH -u BUILD_NUMBER TESTFLIGHT_LOCAL="$tmp/none" ${vars[@]+"${vars[@]}"} \
    "$repo/scripts/native/testflight.sh" --dry-run "$@" >"$out" 2>&1
}
expect() { # <exit> <name> <exit wanted> <text wanted>
  local code=$1 name=$2 want=$3 text=$4
  if [ "$code" = "$want" ] && grep -qF -- "$text" "$out"; then ok "$name"; else
    echo "     exit $code, wanted $want and: $text"
    sed 's/^/     /' "$out"
    bad "$name"
  fi
}

dry
expect $? "no key: stops, naming all three" 78 "ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH not set"
dry ASC_KEY_ID=K ASC_ISSUER_ID=I
expect $? "no key file: names the one missing" 78 "ASC_KEY_PATH not set"
dry ASC_KEY_ID=K ASC_ISSUER_ID=I ASC_KEY_PATH="$tmp/keys/nothing.p8"
expect $? "a key path that names nothing" 78 "names no readable file"
echo key >"$repo/AuthKey_T.p8"
dry ASC_KEY_ID=K ASC_ISSUER_ID=I ASC_KEY_PATH="$repo/AuthKey_T.p8" -- --allow-dirty
expect $? "a key file inside the checkout is refused" 78 "inside the repository"
rm -f "$repo/AuthKey_T.p8"

printf 'ASC_KEY_ID=KEYID123\nASC_ISSUER_ID="ISSUER456"\nASC_KEY_PATH=%s\n' "$tmp/keys/AuthKey_T.p8" >"$tmp/local"
env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_PATH -u BUILD_NUMBER TESTFLIGHT_LOCAL="$tmp/local" \
  "$repo/scripts/native/testflight.sh" --dry-run >"$out" 2>&1
expect $? "the key from the ignored local file: the plan" 0 "upload:  with the App Store Connect key"
grep -qF "testflight: 2.0.0 (2) from" "$out" && ok "the build number is the commit count" || bad "the build number is the commit count"
grep -qE "KEYID123|ISSUER456|AuthKey_T" "$out" && bad "the key's ids and path are never printed" || ok "the key's ids and path are never printed"

dry -- --export-only
expect $? "export only: no key needed" 0 ", export only"
dry BUILD_NUMBER=41 -- --export-only
expect $? "a build number given" 0 "2.0.0 (41)"
dry -- --export-only --build-number 4x
expect $? "a build number that isn't one" 64 "is not a number"

echo change >>"$repo/native/project.yml"
dry -- --export-only
expect $? "uncommitted changes: stops, naming them" 65 "native/project.yml"
dry -- --export-only --allow-dirty
expect $? "uncommitted changes, allowed" 0 ", export only"
(cd "$repo" && git checkout -q -- native/project.yml)
mkdir -p "$repo/native/App" && echo x >"$repo/native/App/New.swift"
dry -- --export-only
expect $? "an untracked source the build would compile" 65 "native/App/"

[ "$fails" = 0 ] || exit 1
