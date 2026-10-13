#!/usr/bin/env bash
# Host test for the device build's signing path (bug-kit#53): `just native-build-device` with fake xcodebuild, lockf,
# ioreg and caffeinate, and BugKit's real signing guard. Nothing signs, nothing takes the real lock.
#   1. unlocked, a clean build: the recipe passes, and the guard ran it (caffeinate held the display)
#   2. "No Accounts" in a build that still printed BUILD SUCCEEDED: the recipe fails with 78, so no install follows
#   3. the Mac locked: the guard waits, and the build does not start
set -uo pipefail
cd "$(dirname "$0")/../.."
guard_dir=""
for d in native/Build/SourcePackages/checkouts/bug-kit/scripts "${BUG_KIT:-$HOME/gits/bug-kit}/scripts"; do
  [ -x "$d/signing-guard.sh" ] && { guard_dir=$d; break; }
done
if [ -z "$guard_dir" ]; then
  echo "test-signing-guard: skipped, no BugKit signing-guard.sh (BugKit 0.3.3 resolves it at the next build)"
  exit 0
fi
guard_dir=$(cd "$guard_dir" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-signing-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fakes=$tmp/bin
mkdir -p "$fakes"
cat >"$fakes/xcodebuild" <<'F'
#!/usr/bin/env bash
case " $* " in *" -resolvePackageDependencies "*) exit 0 ;; esac
echo "xcodebuild $*" >>"$MARKS/build"
[ -n "${FAKE_NO_ACCOUNTS:-}" ] && echo "error: No Accounts: Add a new account in Accounts settings."
echo "** BUILD SUCCEEDED **"
F
cat >"$fakes/xcodegen" <<'F'
#!/usr/bin/env bash
exit 0
F
cat >"$fakes/lockf" <<'F'
#!/usr/bin/env bash
shift
exec "$@"
F
cat >"$fakes/ioreg" <<'F'
#!/usr/bin/env bash
echo "\"CGSSessionScreenIsLocked\"=${FAKE_LOCKED:-No}"
F
cat >"$fakes/caffeinate" <<'F'
#!/usr/bin/env bash
echo "caffeinate $*" >>"$MARKS/awake"
while kill -0 "${@: -1}" 2>/dev/null; do sleep 0.2; done
F
chmod +x "$fakes"/*
fail=0
run() {
  export MARKS=$tmp/marks/$1
  mkdir -p "$MARKS"
  shift
  env "$@" PATH="$fakes:$PATH" MARKS="$MARKS" DEVICE=fake-device NATIVE_LOG_DIR="$tmp/logs" \
    just bugkit_scripts="$guard_dir" native-build-device >"$MARKS/out" 2>&1
}
check() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; sed 's/^/     /' "$MARKS/out"; fail=1; fi
}

run clean
status=$?
check "an unlocked clean build passes" '[ "$status" -eq 0 ]'
check "the guard held the display awake during it" '[ -s "$MARKS/awake" ] && grep -q -- "-d" "$MARKS/awake"'
check "the build ran once" '[ "$(wc -l <"$MARKS/build")" -eq 1 ]'

run noaccounts FAKE_NO_ACCOUNTS=1
status=$?
check "No Accounts fails the recipe with 78" '[ "$status" -eq 78 ]'

export MARKS=$tmp/marks/locked
mkdir -p "$MARKS"
(run locked FAKE_LOCKED=Yes) &
pid=$!
sleep 3
check "the guard is waiting for the Mac to unlock" 'grep -q "Mac is locked; waiting" "$tmp/logs/build-device.log"'
check "a locked Mac starts no build" '[ ! -e "$MARKS/build" ]'
# The waiting guard and its wrappers carry the fake device or this test's directory on their command lines.
pkill -f "id=fake-device" 2>/dev/null
pkill -f "$tmp" 2>/dev/null
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
exit $fail
