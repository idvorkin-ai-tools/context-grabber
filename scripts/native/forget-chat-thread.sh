#!/usr/bin/env bash
# Removes the simulator outbox's messages for one chat thread (#801). The outbox keeps what it sent, and a sent
# message the Cockpit's thread does not hold still shows under it as newer than Larry's last. Each fake Cockpit
# (fake-cockpit.py) starts with its threads as written, so an earlier run's Yes on igor2-88g.629 made the next run's
# Yes an answer to an older message: quoted, not the bare word. Prints how many it removed.
# The simulator must be booted (simctl cannot look a container up otherwise) and the app not running.
# Usage: forget-chat-thread.sh <simulator udid> <bundle id> <thread key>
set -euo pipefail
udid=$1 bundle=$2 thread=$3
command -v jq >/dev/null || { echo "forget-chat-thread: needs jq" >&2; exit 1; }
# The App Group is the bundle id's (InboxStore.appGroup).
container=$(xcrun simctl get_app_container "$udid" "$bundle" "group.$bundle" 2>/dev/null || true)
if [ -z "$container" ]; then
  # No group and no app: a fresh simulator, nothing was ever sent. No group with the app installed is a real failure.
  if xcrun simctl get_app_container "$udid" "$bundle" app >/dev/null 2>&1; then
    echo "forget-chat-thread: $bundle is installed on $udid but its group.$bundle container was not found" >&2
    exit 1
  fi
  echo 0; exit 0
fi
# The group with no Inbox folder: the outbox has never held anything.
[ -n "$container" ] && [ -d "$container/Inbox" ] || { echo 0; exit 0; }
removed=0
for item in "$container/Inbox"/*.json; do
  [ -f "$item" ] || continue
  if jq -e --arg t "$thread" '.thread == $t or .chat_thread == $t' "$item" >/dev/null; then
    rm -f "${item%.json}".*  # the item and what lies beside it under its id (a picture, strokes, a file)
    removed=$((removed + 1))
  fi
done
echo "$removed"
