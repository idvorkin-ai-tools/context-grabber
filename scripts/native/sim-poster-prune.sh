#!/usr/bin/env bash
# Stories 984, 987, 988, 989: every simulator boot writes about 300 MB of PosterBoard wallpaper snapshots (PRBPosterExtensionDataStore)
# that nothing evicts; the iPad simulator reached 3.5 GB in a day. This deletes them on every shut-down simulator, never a
# booted one (PosterBoard holds its store open), and PosterBoard rebuilds them on the next boot. It runs before a boot
# and when a simulator run ends, whatever the free disk, and prints one line. It never fails: a prune is housekeeping,
# not a test, so every error is a line and exit 0.
# Usage: sim-poster-prune.sh   (SIM_DEVICES_DIR overrides ~/Library/Developer/CoreSimulator/Devices, for the self-test)
set -uo pipefail
root=${SIM_DEVICES_DIR:-$HOME/Library/Developer/CoreSimulator/Devices}
states() { xcrun simctl list devices -j </dev/null 2>/dev/null | jq -r '.devices[][] | "\(.udid) \(.state) \(.name)"' 2>/dev/null; }
list=$(states) || true
[ -n "$list" ] || { echo "sim-poster-prune: no simulators listed by simctl; nothing pruned"; exit 0; }
cleared=() kb=0
while IFS=' ' read -r udid state name; do
  [ "$state" = "Shutdown" ] && [ -d "$root/$udid" ] || continue
  stores=$(find "$root/$udid" -maxdepth 8 -type d -name PRBPosterExtensionDataStore -prune 2>/dev/null)
  [ -n "$stores" ] || continue
  freed=0
  while IFS= read -r store; do
    # Booted since the list was read (another run, a person)? Leave it: PosterBoard has it open.
    states | grep -qE "^$udid Shutdown " || continue
    size=$(du -sk "$store" 2>/dev/null | cut -f1)
    rm -rf "$store" 2>/dev/null && freed=$((freed + ${size:-0}))
  done <<<"$stores"
  [ "$freed" -gt 0 ] && cleared+=("$name") && kb=$((kb + freed))
done <<<"$list"
if [ ${#cleared[@]} -eq 0 ]; then
  echo "sim-poster-prune: no wallpaper snapshots on a shut-down simulator"
else
  plural=; [ ${#cleared[@]} -gt 1 ] && plural=s
  names=$(printf '%s, ' "${cleared[@]}")
  echo "sim-poster-prune: cleared the wallpaper snapshots of ${#cleared[@]} shut-down simulator$plural (${names%, }), freed $((kb / 1024)) MB"
fi
exit 0
