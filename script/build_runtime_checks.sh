#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DesktopPongRuntimeChecks"
APP_BUNDLE="$ROOT_DIR/.build/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="$ROOT_DIR/.build/RuntimeModuleCache"
REPORT_PATH="$ROOT_DIR/.build/runtime-acceptance-report.json"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$APP_MACOS" "$MODULE_CACHE"
rm -f "$REPORT_PATH"

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE" \
/Library/Developer/CommandLineTools/usr/bin/swiftc \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -Xfrontend -interface-compiler-version \
  -Xfrontend 6.3.2 \
  "$ROOT_DIR/Sources/DesktopPongOverlay/AuxiliaryWindowControllers.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/GlobalShortcutController.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/HapticFeedbackController.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/InputMonitor.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/MenuBarGameController.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/OverlayWindowController.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PongGameState.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PongScene.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PongSettings.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/PreferencesView.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/StatusMenuController.swift" \
  "$ROOT_DIR/Sources/DesktopPongOverlay/TransparentOverlayPanel.swift" \
  "$ROOT_DIR/Tests/RuntimeAcceptance/main.swift" \
  -o "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.marcustossmann.DesktopPongRuntimeChecks</string>
  <key>CFBundleName</key>
  <string>Desktop Pong Runtime Checks</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSEnvironment</key>
  <dict>
    <key>DESKTOP_PONG_RUNTIME_REPORT</key>
    <string>$REPORT_PATH</string>
    <key>DESKTOP_PONG_SUPPRESS_ACCESSIBILITY_PROMPT</key>
    <string>1</string>
  </dict>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
echo "$APP_BUNDLE"
