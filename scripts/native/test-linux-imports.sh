#!/usr/bin/env bash
# #943: ContextCore builds on Linux only where each file that names a URL-loading type (URLRequest, URLSession,
# URLResponse, HTTPURLResponse) also imports FoundationNetworking under `#if canImport(FoundationNetworking)`: on Linux
# those types live there, not in Foundation. BoardMargin.swift and BoardToText.swift missed it, and nothing on the Mac
# could see it: `just test-linux` runs only on a Linux box. Bead context-grabber-cmk: it also fails on an Apple-only
# framework import (CoreGraphics and the like) that a Linux build of the package's sources or tests would reach,
# judged by swiftc's import prescan for a Linux target, so `#if canImport`/`#if os` branches count as Linux would.
# This runs on the Mac's host rung and on the Linux one.
cd "$(dirname "$0")/../../native/ContextCore" || exit 2
exec python3 ../../scripts/native/check-linux-imports.py
