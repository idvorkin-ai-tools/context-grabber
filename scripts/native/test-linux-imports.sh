#!/usr/bin/env bash
# #943: ContextCore builds on Linux only where each file that names a URL-loading type (URLRequest, URLSession,
# URLResponse, HTTPURLResponse) also imports FoundationNetworking under `#if canImport(FoundationNetworking)`: on Linux
# those types live there, not in Foundation. BoardMargin.swift and BoardToText.swift missed it, and nothing on the Mac
# could see it: `just test-linux` runs only on a Linux box. This runs on the Mac's host rung and on the Linux one.
set -uo pipefail
cd "$(dirname "$0")/../../native/ContextCore/Sources" || exit 2
fail=0
while IFS= read -r file; do
  if ! grep -q 'canImport(FoundationNetworking)' "$file"; then
    echo "FAIL $file uses URLRequest/URLSession without '#if canImport(FoundationNetworking) import FoundationNetworking'"
    fail=1
  fi
done < <(grep -rlE '\b(URLRequest|URLSession|URLResponse|HTTPURLResponse)\b' --include='*.swift' .)
[ $fail -eq 0 ] && echo "ok   every ContextCore file with URL loading imports FoundationNetworking on Linux"
exit $fail
