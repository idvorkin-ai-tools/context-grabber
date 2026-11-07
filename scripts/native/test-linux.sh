#!/usr/bin/env bash
# The Linux rung (context-grabber-bf1): what a Linux box can say about ContextCore without a Mac.
#   1. ContextCore's XCTests, built and run on Linux. Units that need an Apple framework (ImageIO, NSItemProvider,
#      CoreText, JavaScriptCore, PencilKit) are left out by `#if canImport`, and so are their tests; link finding, upload
#      types and the affine transform have Linux stand-ins, so theirs run here too (docs/TESTING.md, Off the Mac).
#   2. ContextCore and its tests cross-built with a Darwin Swift SDK (xtool's) for macOS, iOS and the iOS simulator:
#      Mach-O compiled, never executed. Skipped, and said so, when no `darwin` SDK is installed.
# Neither covers the Xcode targets, signing, Catalyst or anything at runtime on Apple: the Mac's `just native-test` does.
#
# Environment (all optional):
#   LINUX_SWIFT_BIN  the Swift toolchain's bin directory, when `swift` on PATH is not the one to use
#   LINUX_LIB_DIR    extra libraries for the toolchain and the link (LD_LIBRARY_PATH and -L), e.g. an ICU it needs
#   SQLITE_INCLUDE   a directory holding sqlite3.h, when libsqlite3-dev is not installed
#   CG_LINUX_BUILD   a build directory to keep between runs (default: a temporary one, removed afterwards)
#   JOBS             build jobs (default 3)
set -uo pipefail
cd "$(dirname "$0")/../../native/ContextCore"
[ "$(uname -s)" = Linux ] || { echo "test-linux is the Linux rung; on a Mac run just native-test" >&2; exit 2; }
[ -n "${LINUX_SWIFT_BIN:-}" ] && export PATH="$LINUX_SWIFT_BIN:$PATH"
command -v swift >/dev/null || { echo "no swift on PATH (set LINUX_SWIFT_BIN)" >&2; exit 2; }
flags=()
if [ -n "${LINUX_LIB_DIR:-}" ]; then
  export LD_LIBRARY_PATH="$LINUX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  flags+=(-Xlinker "-L$LINUX_LIB_DIR")
fi
[ -n "${SQLITE_INCLUDE:-}" ] && flags+=(-Xcc "-I$SQLITE_INCLUDE")
if [ -z "${SQLITE_INCLUDE:-}" ] && [ ! -e /usr/include/sqlite3.h ]; then
  echo "no sqlite3.h: apt install libsqlite3-dev, or set SQLITE_INCLUDE" >&2
  exit 2
fi
build=${CG_LINUX_BUILD:-}
if [ -z "$build" ]; then
  build=$(mktemp -d "${TMPDIR:-/tmp}/cg-test-linux.XXXXXX")
  trap 'rm -rf "$build"' EXIT
fi
jobs=${JOBS:-3}
low() { nice -n 19 ionice -c 3 "$@"; }
fail=0

echo "== $(swift --version 2>&1 | head -1)"
echo "== Linux: swift test ($(uname -m))"
log=$build/linux-test.log
low swift test -j "$jobs" --scratch-path "$build/linux" "${flags[@]}" >"$log" 2>&1
status=$?
grep -E "error:|Fatal error" "$log" | head -20
summary=$(grep -E "Executed [0-9]+ tests" "$log" | tail -1 | sed 's/^[[:space:]]*//')
if [ $status -ne 0 ] || [ -z "$summary" ]; then
  echo "FAIL Linux swift test (exit $status; log: $log)"
  fail=1
else
  echo "ok   $summary"
fi

if swift sdk list 2>/dev/null | grep -qx darwin; then
  for triple in arm64-apple-macosx arm64-apple-ios arm64-apple-ios-simulator; do
    sdk=$(swift sdk configure --show-configuration darwin "$triple" 2>/dev/null | sed -n 's/^sdkRootPath: //p')
    log=$build/$triple.log
    if low swift build --build-tests --build-system native --swift-sdk darwin --triple "$triple" -j "$jobs" \
      --scratch-path "$build/$triple" >"$log" 2>&1; then
      echo "ok   cross-build $triple: ContextCore + tests compiled, not run (SDK $(basename "${sdk:-?}"))"
    else
      grep -E "error:" "$log" | head -20
      echo "FAIL cross-build $triple (log: $log)"
      fail=1
    fi
  done
else
  echo "SKIP cross-build: no darwin Swift SDK (xtool sdk install)"
fi
# A failure keeps its logs, even in the temporary directory.
if [ $fail -ne 0 ] && [ -z "${CG_LINUX_BUILD:-}" ]; then
  trap - EXIT
  echo "logs kept in $build"
fi
exit $fail
