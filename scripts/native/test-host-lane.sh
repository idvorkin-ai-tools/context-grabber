#!/usr/bin/env bash
# Host test for the host slots (stories 795, 797, 798; context-grabber-mkd0): scripts/native/host-lane.sh with real lockf in a temp
# lock directory, so it never takes or waits on this Mac's own slots.
#   the slot count from the cores and from HOST_LANES; six jobs on four slots never more than four at once, all six run,
#   and the ones that queue say they are waiting for a host slot; the command's own exit status (75 included) kept
#   apart from a busy lock; a holder killed with kill -9 frees its slot at once, and a lock file left behind holds
#   nothing; every slot held past HOST_LANE_WAIT is exit 75 with nothing run.
set -uo pipefail
# The slot settings come from each case, never from this shell or from a host slot this check runs in.
unset HOST_LANES HOST_LANE HOST_LANE_WAIT HOST_LANE_POLL
cd "$(dirname "$0")/../.."
gate=$PWD/scripts/native/host-lane.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-host-lane-test.XXXXXX")
pids=()
cleanup() { local p; for p in "${pids[@]}"; do kill -9 "$p" 2>/dev/null; done; [ ! -s "$tmp/held-pid" ] || kill -9 "$(cat "$tmp/held-pid")" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
export BUILD_LOCK_DIR=$tmp/locks HOST_LANE_POLL=0.1
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
is() { if [ "$2" = "$3" ]; then ok "$1"; else echo "     wanted: $3"; echo "     got:    $2"; bad "$1"; fi; }
# Waits up to 20 s for a condition, polling.
until_() { local i; for ((i = 0; i < 200; i++)); do eval "$1" && return 0; sleep 0.1; done; return 1; }

# --- the count
fakes=$tmp/bin
mkdir -p "$fakes"
printf '#!/usr/bin/env bash\n[ "$*" = "-n hw.ncpu" ] && [ -n "${FAKE_CORES:-}" ] && echo "$FAKE_CORES"\n' >"$fakes/sysctl"
chmod +x "$fakes/sysctl"
is "18 cores: four slots" "$(PATH=$fakes:$PATH FAKE_CORES=18 "$gate" count)" 4
is "64 cores: still four" "$(PATH=$fakes:$PATH FAKE_CORES=64 "$gate" count)" 4
is "8 cores: two" "$(PATH=$fakes:$PATH FAKE_CORES=8 "$gate" count)" 2
is "2 cores: at least one" "$(PATH=$fakes:$PATH FAKE_CORES=2 "$gate" count)" 1
is "HOST_LANES names the count" "$(PATH=$fakes:$PATH FAKE_CORES=18 HOST_LANES=6 "$gate" count)" 6
is "HOST_LANES=0 is one" "$(HOST_LANES=0 "$gate" count)" 1
is "a HOST_LANES that is no number counts the cores" "$(PATH=$fakes:$PATH FAKE_CORES=18 HOST_LANES=many "$gate" count 2>/dev/null)" 4

# --- six jobs, four slots: each job marks itself running, records how many are, and holds until released.
run=$tmp/running go=$tmp/go
mkdir -p "$run"
job() {  # <n>
  HOST_LANES=4 "$gate" run bash -c '
    mkdir "$0/$1"; ls "$0" | wc -l | tr -d " " >>"$0.peaks"; echo "$HOST_LANE" >>"$0.slots"
    while [ ! -e "$2" ]; do sleep 0.05; done; sleep 0.2; rmdir "$0/$1"' "$run" "$1" "$go" 2>"$tmp/err-$1"
  echo $? >"$tmp/exit-$1"
}
for n in 1 2 3 4 5 6; do job "$n" & pids+=($!); done
until_ '[ "$(ls "$run" | wc -l | tr -d " ")" -ge 4 ]' || bad "four jobs started"
sleep 1  # the other two have polled the slots and are waiting
is "four slots, four jobs running" "$(ls "$run" | wc -l | tr -d ' ')" 4
is "the other two said they are waiting for a host slot" "$(cat "$tmp"/err-* | grep -c 'waiting for a host slot')" 2
: >"$go"
until_ '[ "$(ls "$tmp" | grep -c "^exit-")" -eq 6 ]' || bad "all six jobs finished"
is "all six ran" "$(wc -l <"$run.peaks" | tr -d ' ')" 6
is "never more than four at once" "$(sort -n "$run.peaks" | tail -1)" 4
is "every job exited 0" "$(cat "$tmp"/exit-* | sort -u | tr -d '\n')" 0
is "the jobs ran in slots 1 to 4" "$(sort -u "$run.slots" | tr -d '\n')" 1234

# --- the command's own exit status, 75 included, is the command's
HOST_LANES=1 "$gate" run bash -c 'exit 75' 2>"$tmp/err-own"
status=$?
is "a command's own exit 75 comes back once, not retried" "$status" 75
if grep -q 'busy' "$tmp/err-own"; then bad "the command's 75 was not read as a busy slot"; else ok "the command's 75 was not read as a busy slot"; fi
HOST_LANES=1 "$gate" run bash -c 'exit 3' 2>/dev/null
is "a failing command's status" "$?" 3

# --- a stale holder: killed with kill -9, its slot is free at once; a lock file left behind holds nothing
# The holder's command writes its pid and sleeps; killing lockf leaves it running, unseen by the slots, as a killed
# holder's swift would be, so the check kills it itself.
hold() { HOST_LANES=1 "$gate" run bash -c 'echo $$ >"$0"; exec sleep 30' "$tmp/held-pid" 2>/dev/null & holder=$!; pids+=($holder); }
drop() { pkill -9 -P "$holder" 2>/dev/null; kill -9 "$holder" "$(cat "$tmp/held-pid" 2>/dev/null)" 2>/dev/null; { wait "$holder"; } 2>/dev/null; }
hold
until_ '"$gate" busy 1 && [ -s "$tmp/held-pid" ]' || bad "the holder took slot 1"
pids+=($(cat "$tmp/held-pid" 2>/dev/null))
pkill -9 -P "$holder" 2>/dev/null  # lockf, under the gate: the kernel lets its lock go
kill -9 "$holder" 2>/dev/null
{ wait "$holder"; } 2>/dev/null
until_ '! "$gate" busy 1' && ok "a killed holder's slot is free" || bad "a killed holder's slot is free"
[ -e "$("$gate" lock 1)" ] && ok "its lock file is still there" || bad "its lock file is still there"
start=$SECONDS
out=$(HOST_LANES=1 HOST_LANE_WAIT=5 "$gate" run echo ran 2>"$tmp/err-stale")
is "the next job runs at once in the left-behind lock" "$out" ran
if grep -q 'waiting' "$tmp/err-stale" || [ $((SECONDS - start)) -ge 3 ]; then bad "it did not wait"; else ok "it did not wait"; fi

# --- every slot held past HOST_LANE_WAIT: exit 75, nothing run
kill -9 "$(cat "$tmp/held-pid" 2>/dev/null)" 2>/dev/null
rm -f "$tmp/held-pid"
hold
until_ '"$gate" busy 1' || bad "the holder took slot 1 again"
HOST_LANES=1 HOST_LANE_WAIT=1 "$gate" run touch "$tmp/should-not" 2>"$tmp/err-wait"
is "all slots busy past the wait: exit 75" "$?" 75
[ -e "$tmp/should-not" ] && bad "nothing ran" || ok "nothing ran"
grep -q 'still busy' "$tmp/err-wait" && ok "it says the slots stayed busy" || bad "it says the slots stayed busy"
drop

exit "$fail"
