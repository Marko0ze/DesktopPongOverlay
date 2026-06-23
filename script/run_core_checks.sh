#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"
CHECK_BINARY="$ROOT_DIR/.build/core-checks"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$MODULE_CACHE"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE" \
/Library/Developer/CommandLineTools/usr/bin/swiftc \
  -sdk "$SDK_PATH" \
  -Xfrontend -interface-compiler-version \
  -Xfrontend 6.3.2 \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PongSettings.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PongGameState.swift" \
  "$ROOT_DIR/Tests/CoreChecks/main.swift" \
  -o "$CHECK_BINARY"

"$CHECK_BINARY"
