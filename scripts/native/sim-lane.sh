# shellcheck shell=bash
# Simulator lane selection and guards (stories 1508–1510, bead context-grabber-w7nl).
# Sourced by sim-smoke.sh, sim-boot.sh, xcodebuild-log.sh, test-chat-ui.sh and test-whiteboard-ui.sh.
#   take_lane <script> <args…>  outside any lane, runs the script again in the first free one (build-lane.sh run),
#                               marked SIM_LANE_TAKEN, so a simulator udid it was given means that model in the lane's
#                               own copy. Inside a lane it does nothing.
#   lane_target <udid|name>     the name to resolve in this lane: a lane's udid given to a run that took its own lane is
#                               read as its model ("iPad Pro 11-inch (M5) lane 2" -> "iPad Pro 11-inch (M5)"), so
#                               sim-udid.sh finds this lane's copy; anything else is passed on as given.
#   sim_owner <udid|name>       the lane that owns the simulator: N for "<model> lane N", 1 for a lane model's own name
#                               (SIM, WHITEBOARD_SIM, iPhone 17, iPad Pro 11-inch (M5)); nothing for a simulator of no
#                               lane, or a udid this Mac doesn't have (a test's fake id).
#   sim_lane_guard <udid|name> <what>  returns 0 when this run may drive the simulator: it belongs to no lane, or to
#                               BUILD_LANE. Otherwise says why and how to run it, and returns 64.
sim_lane_here=$(dirname "${BASH_SOURCE[0]}")

take_lane() {
  [ -z "${BUILD_LANE:-}" ] || return 0
  echo "${1##*/}: not in a build lane, so taking one: a simulator is driven only from the lane that owns it (story 1508)" >&2
  exec "$sim_lane_here/build-lane.sh" run env SIM_LANE_TAKEN=1 bash "$@"
}

take_lane_one() {
  [ -z "${BUILD_LANE:-}" ] || return 0
  local lock lanes
  lock=$("$sim_lane_here/build-lane.sh" lock 1) || return
  lanes=$("$sim_lane_here/build-lane.sh" count) || return
  mkdir -p "${lock%/*}" || return
  exec lockf -k -t "${BUILD_LANE_WAIT:-3600}" "$lock" env BUILD_LANE=1 BUILD_LANES="$lanes" BUILD_LANE_PORT_OFFSET=0 "$@"
}

sim_name() {  # <udid|name>: the simulator's name, or nothing for a udid this Mac doesn't have
  if [[ $1 =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    xcrun simctl list devices available 2>/dev/null | sed -nE "s/^ +(.+) \\($1\\) \\(.*$/\\1/Ip" | head -1
  else
    echo "$1"
  fi
}

sim_owner() {  # <udid|name>
  local name laned='^(.+) lane ([0-9]+)$'
  name=$(sim_name "$1")
  [ -n "$name" ] || return 0
  if [[ $name =~ $laned ]]; then echo "${BASH_REMATCH[2]}"; return 0; fi
  case "$name" in
    "${SIM:-iPhone 17}" | "${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}" | "iPhone 17" | "iPad Pro 11-inch (M5)") echo 1 ;;
  esac
  return 0
}

lane_target() {  # <udid|name>
  local name laned='^(.+) lane ([0-9]+)$'
  if [ -n "${SIM_LANE_TAKEN:-}" ] && [[ $1 =~ ^[0-9A-Fa-f-]{36}$ ]] && [ -n "$(sim_owner "$1")" ]; then
    name=$(sim_name "$1")
    [[ $name =~ $laned ]] && name=${BASH_REMATCH[1]}
    echo "$name"
  else
    echo "$1"
  fi
}

sim_lane_guard() {  # <udid|name> <what>
  local owner
  owner=$(sim_owner "$1")
  [ -n "$owner" ] || return 0
  [ "${BUILD_LANE:-}" = "$owner" ] && return 0
  if [ -z "${BUILD_LANE:-}" ]; then
    echo "$2: refused: the simulator '$1' is build lane $owner's and this run holds no lane, so it could drive it under another job's tests (story 1508). Run it in a lane: scripts/native/build-lane.sh run <this command>, or a just recipe or the ladder, which take one." >&2
  else
    echo "$2: refused: the simulator '$1' is build lane $owner's and this run holds lane $BUILD_LANE (story 1508). Use this lane's own: scripts/native/sim-udid.sh <model name> inside the lane." >&2
  fi
  return 64
}
