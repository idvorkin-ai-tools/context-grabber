#!/usr/bin/env bash
# #943: ContextCore builds on Linux only where each file that names a URL-loading type (URLRequest, URLSession,
# URLResponse, HTTPURLResponse) also imports FoundationNetworking under `#if canImport(FoundationNetworking)`: on Linux
# those types live there, not in Foundation. BoardMargin.swift and BoardToText.swift missed it, and nothing on the Mac
# could see it: `just test-linux` runs only on a Linux box. This runs on the Mac's host rung and on the Linux one.
# Second (context-grabber-cmk): every import of an Apple-only framework (CoreGraphics, CoreText, ImageIO, UIKit, ...)
# in the package's sources and tests (ContextCore, BoardCore, ChatWireKit, the executables, both test bundles) sits
# inside an `#if canImport(...)` or `#if os(...)` block: Linux has no such modules (Foundation there carries CGFloat,
# CGPoint, CGSize and CGRect; Platform/LinuxGeometry.swift the rest). BoardRoomBandTests and PaperProbeMoveAuditTests
# imported CoreGraphics bare and only the Linux box saw it.
set -uo pipefail
cd "$(dirname "$0")/../../native/ContextCore/Sources" || exit 2
fail=0
while IFS= read -r file; do
  if ! grep -A1 -E '^[[:space:]]*#if canImport\(FoundationNetworking\)[[:space:]]*$' "$file" \
    | grep -qE '^[[:space:]]*import FoundationNetworking[[:space:]]*$'; then
    echo "FAIL $file uses URLRequest/URLSession without '#if canImport(FoundationNetworking) import FoundationNetworking'"
    fail=1
  fi
done < <(grep -rlE '\b(URLRequest|URLSession|URLResponse|HTTPURLResponse)\b' --include='*.swift' .)
[ $fail -eq 0 ] && echo "ok   every ContextCore file with URL loading imports FoundationNetworking on Linux"

cd .. || exit 2
apple='CoreGraphics|CoreText|ImageIO|UIKit|AppKit|QuartzCore|SwiftUI|Combine|os|OSLog|Darwin|ObjectiveC|UniformTypeIdentifiers|JavaScriptCore|PencilKit|AVFoundation|AVFAudio|HealthKit|CoreLocation|MapKit|WidgetKit|ActivityKit|AppIntents|SQLite3|Security|CryptoKit|CloudKit|LinkPresentation|Network|UserNotifications|Speech|NaturalLanguage|Vision|CoreImage|CoreMedia|CoreMotion|WebKit|MetricKit|BackgroundTasks|EventKit|Contacts|Photos|PhotosUI|StoreKit'
out=$(find Sources Tests -name '*.swift' -not -path '*/Fixtures/*' -print0 | xargs -0 awk -v apple="^(${apple})$" '
  FNR == 1 { depth = 0 }
  /^[[:space:]]*#if[[:space:]]/ { cond[++depth] = $0; next }
  /^[[:space:]]*#elseif[[:space:]]/ { cond[depth] = $0; next }
  /^[[:space:]]*#else([[:space:]]|$)/ { cond[depth] = "#else"; next }
  /^[[:space:]]*#endif/ { if (depth > 0) depth--; next }
  /^[[:space:]]*(@[_a-zA-Z]+[[:space:]]+)*import[[:space:]]+[A-Za-z0-9_]+[[:space:]]*$/ {
    module = $NF
    if (module !~ apple) next
    guarded = 0
    for (i = 1; i <= depth; i++)
      if (cond[i] ~ /canImport\(|os\((macOS|iOS|watchOS|tvOS|visionOS)\)/ && cond[i] !~ /!/) guarded = 1
    if (!guarded) printf "FAIL %s:%d imports %s outside #if canImport(%s)\n", FILENAME, FNR, module, module
  }')
if [ -n "$out" ]; then
  echo "$out"
  echo "     Linux has no $(echo "$out" | awk '{print $4}' | sort -u | paste -sd, -); wrap the import in #if canImport(...) #endif"
  fail=1
else
  echo "ok   every Apple-only import in ContextCore's sources and tests is behind #if canImport (Linux builds them)"
fi
exit $fail
