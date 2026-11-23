#!/usr/bin/env bash
# Story 1503 (spec docs/superpowers/specs/2026-11-22-board-rules-on-the-web-design.md): the board's rules as
# WebAssembly for the Cockpit's web board. Builds the BoardWasm reactor for WASI, release and stripped, writes it to
# native/Build/wasm/BoardWasm.wasm (or $WASM_OUT) and prints its size, gzipped size and sha256.
#
# Needs a Swift toolchain and its matching wasm SDK (`swift sdk install <the swift.org wasm SDK for that release>`).
# Environment (all optional):
#   WASM_SDK         the SDK to build with (default: the first non-embedded wasm SDK `swift sdk list` shows)
#   LINUX_SWIFT_BIN  the Swift toolchain's bin directory, when `swift` on PATH is not the one to use
#   LINUX_LIB_DIR    extra libraries the toolchain needs (LD_LIBRARY_PATH), as for just test-linux. SwiftPM drops
#                    LD_LIBRARY_PATH when it runs the linker, so wasm-ld then goes through a wrapper that sets it.
#   WASM_BUILD       the build directory (default native/Build/wasm/build, kept between runs)
#   WASM_OUT         where the module goes (default native/Build/wasm/BoardWasm.wasm)
# Exits 3, saying so, when there is no wasm SDK: the caller decides whether that is a skip.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
[ -n "${LINUX_SWIFT_BIN:-}" ] && export PATH="$LINUX_SWIFT_BIN:$PATH"
[ -n "${LINUX_LIB_DIR:-}" ] && export LD_LIBRARY_PATH="$LINUX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
command -v swift >/dev/null || { echo "no swift on PATH (set LINUX_SWIFT_BIN)" >&2; exit 2; }
sdk=${WASM_SDK:-$(swift sdk list 2>/dev/null | grep -i wasm | grep -vi embedded | head -1 || true)}
[ -n "$sdk" ] || { echo "skipped: no wasm Swift SDK installed (swift sdk list shows none; set WASM_SDK)" >&2; exit 3; }
build=${WASM_BUILD:-$root/native/Build/wasm/build}
out=${WASM_OUT:-$root/native/Build/wasm/BoardWasm.wasm}
mkdir -p "$build" "$(dirname "$out")"
build=$(cd "$build" && pwd)

flags=(-Xlinker --strip-all)
if [ -n "${LINUX_LIB_DIR:-}" ]; then
  # The toolchain's own wasm-ld, wrapped with the library path SwiftPM would otherwise drop.
  resource=$(swiftc -print-target-info | python3 -c 'import json, sys; print(json.load(sys.stdin)["paths"]["runtimeResourcePath"])')
  ld="$resource/../../bin/wasm-ld"
  [ -x "$ld" ] || { echo "no wasm-ld beside the toolchain ($ld)" >&2; exit 2; }
  lib=$(cd "$LINUX_LIB_DIR" && pwd)
  printf '#!/bin/sh\nLD_LIBRARY_PATH=%q exec %q "$@"\n' "$lib" "$(cd "$(dirname "$ld")" && pwd)/wasm-ld" >"$build/wasm-ld"
  chmod +x "$build/wasm-ld"
  flags+=(-Xswiftc "-use-ld=$build/wasm-ld")
fi

echo "== BoardWasm for $sdk"
cd "$root/native/ContextCore"
log=$build/build.log
if ! nice -n 19 swift build --swift-sdk "$sdk" --product BoardWasm -c release -j "${JOBS:-3}" \
  --scratch-path "$build" "${flags[@]}" >"$log" 2>&1; then
  grep -E "error:" "$log" | grep -v "^ *-" | head -20
  echo "FAIL BoardWasm build (log: $log)"
  exit 1
fi
cp -f "$(swift build --swift-sdk "$sdk" -c release --scratch-path "$build" --show-bin-path)/BoardWasm.wasm" "$out"
bytes=$(wc -c <"$out" | tr -d ' ')
gz=$(gzip -9 -c "$out" | wc -c | tr -d ' ')
echo "ok   $out: $bytes bytes ($gz gzipped), sha256 $(sha256sum "$out" | cut -d' ' -f1)"
