#!/usr/bin/env bash
# Host test for the build lanes (story 785, #954; stories 980, 985): scripts/native/build-lane.sh, sim-udid.sh,
# sim-boot.sh and xcodebuild-idle.sh with fake lockf, xcrun (simctl), sysctl and pgrep, so nothing takes a real lock,
# nothing boots, and this Mac's own memory and xcodebuilds can't change what it sees.
#   the lane count from the memory and from BUILD_LANES; the first free lane's lock; a command's own exit 75 kept apart
#   from a busy lock; one lane exactly the old lockf; lane N's simulator named and cloned once under lane 1's lock, or
#   made fresh when lane 1 stays busy; sim-boot leaving a busy lane's simulator booted and keeping the booted count at
#   or under the lanes; the xcodebuild wait's threshold; and one lane shutting every other simulator down as before.
set -uo pipefail
cd "$(dirname "$0")/../.."
lane=scripts/native/build-lane.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-build-lane-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
out=$tmp/out
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; sed 's/^/     /' "$out" 2>/dev/null; fail=1; }
is() { if [ "$2" = "$3" ]; then ok "$1"; else echo "     wanted: $3"; echo "     got:    $2"; bad "$1"; fi; }
has() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else echo "     wanted in ${2##*/}: $3"; bad "$1"; fi; }
lacks() { if grep -qF -- "$3" "$2" 2>/dev/null; then echo "     unwanted in ${2##*/}: $3"; bad "$1"; else ok "$1"; fi; }

fakes=$tmp/bin
mkdir -p "$fakes"
export MARKS=$tmp/marks STATE=$tmp/state
# lockf -k -t <seconds> <file> <command…>: a lock named in FAKE_HELD is another job's, so it times out (75).
cat >"$fakes/lockf" <<'F'
#!/usr/bin/env bash
echo "lockf $2 $3 ${4##*/}" >>"$MARKS/lockf"
case " ${FAKE_HELD:-} " in *" ${4##*/} "*) echo "lockf: $4: already locked" >&2; exit 75 ;; esac
shift 4
exec "$@"
F
cat >"$fakes/sysctl" <<'F'
#!/usr/bin/env bash
[ "$*" = "-n hw.memsize" ] && [ -n "${FAKE_MEM:-}" ] || exit 1
echo "$FAKE_MEM"
F
cat >"$fakes/pgrep" <<'F'
#!/usr/bin/env bash
n=${FAKE_XCODEBUILDS:-0}
[ "$n" -gt 0 ] || exit 1
for ((i = 0; i < n; i++)); do echo $((100 + i)); done
F
# simctl over a state file of "udid|state|name|device type|runtime" lines.
cat >"$fakes/xcrun" <<'F'
#!/usr/bin/env bash
db=$STATE/devices
echo "xcrun $*" >>"$MARKS/xcrun"
[ "$1" = simctl ] || exit 1
shift
set_state() { awk -F'|' -v OFS='|' -v u="$1" -v s="$2" '$1 == u { $2 = s } { print }' "$db" >"$db.new" && mv -f "$db.new" "$db"; }
add() {  # <name> <type> <runtime>
  local n udid
  n=$(($(wc -l <"$db") + 1))
  udid=$(printf '00000000-0000-0000-0000-%012d' "$((90 + n))")
  echo "$udid|Shutdown|$1|$2|$3" >>"$db"
  echo "$udid"
}
case "$1 $2 ${3:-}" in
  "list devices available")
    echo "== Devices =="; echo "-- iOS 27.0 --"
    while IFS='|' read -r u s n _ _; do echo "    $n ($u) ($s) "; done <"$db" ;;
  "list devices booted")
    echo "== Devices =="; echo "-- iOS 27.0 --"
    while IFS='|' read -r u s n _ _; do [ "$s" = Booted ] && echo "    $n ($u) ($s) "; done <"$db" ;;
  "list devices -j")
    jq -Rn '[inputs | split("|") | {udid: .[0], state: .[1], name: .[2], deviceTypeIdentifier: .[3], rt: .[4]}]
      | {devices: (group_by(.rt) | map({key: .[0].rt, value: map(del(.rt))}) | from_entries)}' <"$db" ;;
  shutdown*) set_state "$2" Shutdown ;;
  bootstatus*) set_state "$2" Booted ;;
  clone*)
    line=$(grep "^$2|" "$db") || exit 1
    IFS='|' read -r _ _ _ type rt <<<"$line"
    add "$3" "$type" "$rt" ;;
  create*) add "$2" "$3" "$4" ;;
esac
exit 0
F
chmod +x "$fakes"/*
PHONE=00000000-0000-0000-0000-000000000001 PAD=00000000-0000-0000-0000-000000000002
L2PHONE=00000000-0000-0000-0000-000000000003 L2PAD=00000000-0000-0000-0000-000000000004
L3PHONE=00000000-0000-0000-0000-000000000005 OTHER=00000000-0000-0000-0000-000000000006
IPHONE=com.apple.CoreSimulator.SimDeviceType.iPhone-17 RT=com.apple.CoreSimulator.SimRuntime.iOS-27-0
devices() {  # <udid:state:name>… lines, every one an iPhone 17 on iOS 27
  rm -rf "$MARKS" "$STATE"
  mkdir -p "$MARKS" "$STATE" "$tmp/simdevices"
  : >"$STATE/devices"
  local d
  for d in "$@"; do
    IFS=: read -r u s n <<<"$d"
    echo "$u|$s|$n|$IPHONE|$RT" >>"$STATE/devices"
  done
}
state_of() { awk -F'|' -v u="$1" '$1 == u { print $2 }' "$STATE/devices"; }
with() { env PATH="$fakes:$PATH" BUILD_LOCK_DIR="$tmp/locks" SIM_DEVICES_DIR="$tmp/simdevices" "$@"; }
count() { with "$@" "$lane" count 2>"$out"; }

# The lane count.
is "48 GB: four lanes" "$(count FAKE_MEM=51539607552)" 4
is "16 GB: one lane" "$(count FAKE_MEM=17179869184)" 1
is "96 GB: still four, the most" "$(count FAKE_MEM=103079215104)" 4
is "36 GB: three" "$(count FAKE_MEM=38654705664)" 3
is "8 GB: one, the least" "$(count FAKE_MEM=8589934592)" 1
is "no memory figure (Linux): one" "$(count)" 1
is "BUILD_LANES names the count" "$(count FAKE_MEM=17179869184 BUILD_LANES=2)" 2
is "BUILD_LANES=0 is still one" "$(count BUILD_LANES=0)" 1
is "a BUILD_LANES that isn't a number: the memory's" "$(count FAKE_MEM=51539607552 BUILD_LANES=many)" 4
is "lane 1's lock is the old build.lock" "$(with "$lane" lock 1)" "$tmp/locks/build.lock"
is "lane 3's lock" "$(with "$lane" lock 3)" "$tmp/locks/build-3.lock"

# Taking a lane.
job='echo "lane=$BUILD_LANE of=$BUILD_LANES ports=+$BUILD_LANE_PORT_OFFSET"'
devices
got=$(with BUILD_LANES=4 FAKE_HELD="build.lock build-2.lock" "$lane" run bash -c "$job" 2>&1)
has "lanes 1 and 2 busy: the job runs in lane 3" <(echo "$got") "lane=3 of=4 ports=+20"
has "and says which lane it got" <(echo "$got") "build lane 3 of 4"
lacks "lanes 1 and 2 busy: never run under their locks" "$MARKS/lockf" "-t 0 build.lock bash"
devices
got=$(with BUILD_LANES=4 "$lane" run bash -c "$job" 2>&1)
has "all free: the first lane" <(echo "$got") "lane=1 of=4 ports=+0"
devices
with BUILD_LANES=4 "$lane" run bash -c 'echo ran >>"$MARKS/ran"; exit 75' >"$out" 2>&1
status=$?
is "a command's own exit 75 is its exit" "$status" 75
is "and it ran once, not again in the next lane" "$(wc -l <"$MARKS/ran" | tr -d ' ')" 1
devices
with BUILD_LANES=3 BUILD_LANE_WAIT=0 FAKE_HELD="build.lock build-2.lock build-3.lock" "$lane" run touch "$MARKS/ran" >"$out" 2>&1
status=$?
is "every lane busy past the wait: exit 75" "$status" 75
has "every lane busy: says so" "$out" "all 3 build lanes were still busy"
[ ! -e "$MARKS/ran" ] && ok "every lane busy: nothing ran" || bad "every lane busy: nothing ran"
devices
got=$(with BUILD_LANES=1 "$lane" run bash -c "$job" 2>&1)
is "one lane: the old lockf on build.lock, waiting an hour" "$(cat "$MARKS/lockf")" "lockf -t 3600 build.lock"
is "one lane: the job sees lane 1" "$got" "lane=1 of=1 ports=+0"

# Lane N's simulator.
devices "$PHONE:Shutdown:iPhone 17" "$L2PHONE:Shutdown:iPhone 17 lane 2"
is "lane 1: the named simulator" "$(with BUILD_LANES=4 BUILD_LANE=1 scripts/native/sim-udid.sh "iPhone 17")" "$PHONE"
is "no lane (outside one): the named simulator" "$(with BUILD_LANES=4 scripts/native/sim-udid.sh "iPhone 17")" "$PHONE"
is "lane 2: its own copy" "$(with BUILD_LANES=4 BUILD_LANE=2 scripts/native/sim-udid.sh "iPhone 17")" "$L2PHONE"
is "a lane's name is taken as it is" "$(with BUILD_LANE=2 "$lane" sim "iPhone 17 lane 2")" "iPhone 17 lane 2"
is "a udid is taken as it is" "$(with BUILD_LANE=3 scripts/native/sim-udid.sh "$PHONE")" "$PHONE"
lacks "an existing copy: nothing cloned" "$MARKS/xcrun" "simctl clone"
devices "$PHONE:Booted:iPhone 17"
got=$(with BUILD_LANES=4 BUILD_LANE=3 scripts/native/sim-udid.sh "iPhone 17" 2>"$out")
is "lane 3's first time: lane 1's copied" "$(grep -c "simctl clone $PHONE iPhone 17 lane 3" "$MARKS/xcrun")" 1
has "the copy is made under lane 1's lock" "$MARKS/lockf" "lockf -t 600 build.lock"
is "lane 1's simulator is shut down to be copied" "$(state_of "$PHONE")" Shutdown
is "the copy's udid comes back" "$got" "$(awk -F'|' '$3 == "iPhone 17 lane 3" { print $1 }' "$STATE/devices")"
with BUILD_LANES=4 BUILD_LANE=3 scripts/native/sim-udid.sh "iPhone 17" >/dev/null 2>&1
is "made once: the second look clones nothing" "$(grep -c "simctl clone" "$MARKS/xcrun")" 1
devices "$PHONE:Booted:iPhone 17"
with BUILD_LANES=4 BUILD_LANE=2 BUILD_LANE_CLONE_WAIT=0 FAKE_HELD=build.lock scripts/native/sim-udid.sh "iPhone 17" >/dev/null 2>"$out"
lacks "lane 1 busy: its simulator isn't touched" "$MARKS/xcrun" "simctl shutdown $PHONE"
has "lane 1 busy: a fresh one of the same model and runtime" "$MARKS/xcrun" "simctl create iPhone 17 lane 2 $IPHONE $RT"
has "lane 1 busy: says Health needs granting once" "$out" "BUILD_LANE=2 just native-sim-health"
devices "$PHONE:Shutdown:iPhone 17"
with BUILD_LANES=1 BUILD_LANE=1 "$lane" sims >"$out" 2>&1
has "sims on one lane: nothing to make" "$out" "one build lane on this Mac"

# sim-boot.sh with lanes.
boot() { with "$@" scripts/native/sim-boot.sh "${TARGET:?}" >"$out" 2>&1; }
devices "$PHONE:Booted:iPhone 17" "$L2PHONE:Shutdown:iPhone 17 lane 2" "$L2PAD:Booted:iPad Pro 11-inch (M5) lane 2" \
  "$OTHER:Booted:iPhone 16e" "$L3PHONE:Booted:iPhone 17 lane 3"
TARGET=$L2PHONE boot BUILD_LANES=4 BUILD_LANE=2 FAKE_HELD=build.lock
is "a busy lane's simulator is left booted" "$(state_of "$PHONE")" Booted
has "and it says why" "$out" "leaving 'iPhone 17' booted: build lane 1 is busy"
is "the lane's other device is shut down" "$(state_of "$L2PAD")" Shutdown
is "a simulator of no lane is shut down" "$(state_of "$OTHER")" Shutdown
is "an idle lane's, within the lane count, stays booted" "$(state_of "$L3PHONE")" Booted
is "the target is booted" "$(state_of "$L2PHONE")" Booted
devices "$PHONE:Booted:iPhone 17" "$L2PHONE:Shutdown:iPhone 17 lane 2" "$L3PHONE:Booted:iPhone 17 lane 3"
TARGET=$L2PHONE boot BUILD_LANES=2 BUILD_LANE=2
booted=$(grep -c '|Booted|' "$STATE/devices")
is "two lanes, two idle up: one shut down, two booted with the target" "$booted" 2
has "the idle one goes under its lane's lock" "$MARKS/lockf" "lockf -t 0 build"
devices "$PHONE:Booted:iPhone 17" "$L3PHONE:Booted:iPhone 17 lane 3" "$L2PHONE:Shutdown:iPhone 17 lane 2"
TARGET=$L2PHONE boot BUILD_LANES=2 BUILD_LANE=2 FAKE_HELD="build.lock build-3.lock"
is "past the count, but both busy: neither is shut down" "$(state_of "$PHONE")$(state_of "$L3PHONE")" BootedBooted
devices "$PHONE:Booted:iPhone 17" "$PAD:Booted:iPad Pro 11-inch (M5)" "$L2PAD:Booted:iPad Pro 11-inch (M5) lane 2"
TARGET=$PHONE boot BUILD_LANES=4 BUILD_LANE=1 FAKE_HELD=build-2.lock
is "lane 1 moving to its phone: its iPad is shut down" "$(state_of "$PAD")" Shutdown
is "and lane 2's busy iPad is not" "$(state_of "$L2PAD")" Booted
# One lane: every other booted simulator shut down, exactly as before lanes, whatever else holds a lock.
devices "$PHONE:Shutdown:iPhone 17" "$PAD:Booted:iPad Pro 11-inch (M5)" "$L2PHONE:Booted:iPhone 17 lane 2" "$OTHER:Booted:iPhone 16e"
TARGET="iPhone 17" boot BUILD_LANES=1 BUILD_LANE=1 FAKE_HELD=build-2.lock
is "one lane: only the target is booted" "$(grep '|Booted|' "$STATE/devices" | cut -d'|' -f1)" "$PHONE"
[ ! -e "$MARKS/lockf" ] && ok "one lane: sim-boot asks no lock" || bad "one lane: sim-boot asks no lock"

# The wait for other xcodebuilds.
idle() { with XCODEBUILD_IDLE_WAIT=0 XCODEBUILD_IDLE_POLL=1 "$@" scripts/native/xcodebuild-idle.sh >"$out" 2>&1; }
idle BUILD_LANES=4 FAKE_XCODEBUILDS=3
is "four lanes, three others: it starts" "$?" 0
idle BUILD_LANES=4 FAKE_XCODEBUILDS=4
is "four lanes, four others: refused at the wait's end" "$?" 75
has "four lanes, four others: says why" "$out" "4 other xcodebuilds are running, as many as this Mac's 4 build lanes"
idle BUILD_LANES=1 FAKE_XCODEBUILDS=0
is "one lane, none running: it starts" "$?" 0
idle BUILD_LANES=1 FAKE_XCODEBUILDS=1
is "one lane, one other: refused, as before" "$?" 75
has "one lane: the old line" "$out" "another xcodebuild is running: waiting up to 0s, because a simulator run under contention counts as failed"

[ "$fail" -eq 0 ] && echo "test-build-lane: all passed"
exit "$fail"
