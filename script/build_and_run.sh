#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DesktopPongOverlay"
BUNDLE_ID="com.marcustossmann.DesktopPongOverlay"
MIN_SYSTEM_VERSION="26.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"
SWIFTPM_CACHE="$ROOT_DIR/.build/SwiftPMCache"
export SWIFT_EXEC_MANIFEST="$ROOT_DIR/script/swiftc_compat.sh"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE"
SWIFT_BUILD_FLAGS=(
  --disable-sandbox
  --cache-path "$SWIFTPM_CACHE"
  --manifest-cache local
  -Xswiftc -Xfrontend
  -Xswiftc -interface-compiler-version
  -Xswiftc -Xfrontend
  -Xswiftc 6.3.2
)
ARM_BUILD_FLAGS=(
  "${SWIFT_BUILD_FLAGS[@]}"
  --scratch-path "$ROOT_DIR/.build/arm64-build"
)
X86_BUILD_FLAGS=(
  "${SWIFT_BUILD_FLAGS[@]}"
  --scratch-path "$ROOT_DIR/.build/x86_64-build"
  --triple x86_64-apple-macosx26.0
)

pkill -f "$APP_BINARY" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
mkdir -p "$MODULE_CACHE" "$SWIFTPM_CACHE"
swift build "${ARM_BUILD_FLAGS[@]}"
BUILD_BINARY="$(swift build "${ARM_BUILD_FLAGS[@]}" --show-bin-path)/$APP_NAME"
swift build "${X86_BUILD_FLAGS[@]}"
X86_BUILD_BINARY="$(swift build "${X86_BUILD_FLAGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
/usr/bin/lipo -create "$BUILD_BINARY" "$X86_BUILD_BINARY" -output "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Desktop Pong Overlay</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --options runtime --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" || {
    sleep 0.5
    /usr/bin/open -n "$APP_BUNDLE"
  }
}

case "$MODE" in
  --build|build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -f "$APP_BINARY" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
