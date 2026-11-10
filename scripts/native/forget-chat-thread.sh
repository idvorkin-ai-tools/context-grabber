#!/usr/bin/env bash
# Removes the simulator outbox's messages for one chat thread (#801). The outbox keeps what it sent, and a sent
# message the Cockpit's thread does not hold still shows under it as newer than Larry's last. Each fake Cockpit
# (fake-cockpit.py) starts with its threads as written, so an earlier run's Yes on igor2-88g.629 made the next run's
# Yes an answer to an older message: quoted, not the bare word. Prints how many it removed.
# Usage: forget-chat-thread.sh <simulator udid> <bundle id> <thread key>
set -euo pipefail
udid=$1 bundle=$2 thread=$3
# The App Group is the bundle id's (InboxStore.appGroup); no container yet means nothing was ever sent.
inbox="$(xcrun simctl get_app_container "$udid" "$bundle" "group.$bundle" 2>/dev/null || true)/Inbox"
removed=0
for item in "$inbox"/*.json; do
  [ -f "$item" ] || continue
  # Text only: these threads' messages carry no picture or file beside the item.
  if jq -e --arg t "$thread" '.thread == $t or .chat_thread == $t' "$item" >/dev/null 2>&1; then
    rm -f "$item"
    removed=$((removed + 1))
  fi
done
echo "$removed"
