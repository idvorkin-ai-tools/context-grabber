#!/usr/bin/env bash
# Stages: board wasm (build + node replay), board-ops harness, Linux-runnable script checks. Args: <tree> <out>
set -uo pipefail
tree=$1; out=$2
L=$HOME/tmp/agent/skill/walk-the-store/swiftlib
INC=$HOME/tmp/agent/skill/swift-deps/root/usr/include
export PATH=$HOME/.local/share/swiftly/toolchains/6.4.2/usr/bin:$PATH LINUX_LIB_DIR=$L JOBS=2
export WASM_BUILD=$out/wasm-build WASM_OUT=$out/BoardWasm.wasm
nice -n 19 ionice -c 3 timeout -k 30 2400 "$tree/scripts/native/test-board-wasm.sh" >"$out/wasm.log" 2>&1
echo $? >"$out/wasm.rc"
cd "$tree/native/ContextCore"
fx=Tests/ContextCoreTests/Fixtures/board-ops
LD_LIBRARY_PATH=$L nice -n 19 timeout -k 30 1200 swift run -j 2 --scratch-path "$out/linux" -Xlinker -L$L -Xcc -I$INC board-ops-harness \
  --board "$fx/judge-board.json" --ops "$fx/judge-ops.json" --out "$out/board-ops/judge" >"$out/board-ops.log" 2>&1 \
  && grep -q '<svg' "$out/board-ops/judge.svg" && grep -Eq '"action" ?: ?"applied"' "$out/board-ops/judge.result.json"
echo $? >"$out/board-ops.rc"
