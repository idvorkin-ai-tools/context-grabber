#!/usr/bin/env bash
# Story 1503: builds the board's rules as WebAssembly (scripts/native/build-wasm.sh, same settings) and replays the
# recorded board sessions through the module under node (scripts/native/test-board-wasm.mjs). Says it skipped, and
# exits 0, on a box with no wasm Swift SDK; any other failure fails.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${WASM_OUT:-$here/../../native/Build/wasm/BoardWasm.wasm}
"$here/build-wasm.sh"
status=$?
[ $status -eq 3 ] && { echo "skip board wasm: no wasm Swift SDK"; exit 0; }
[ $status -eq 0 ] || exit $status
command -v node >/dev/null || { echo "FAIL board wasm: no node on PATH"; exit 1; }
WASM_OUT="$out" node --no-warnings "$here/test-board-wasm.mjs" "$out"
