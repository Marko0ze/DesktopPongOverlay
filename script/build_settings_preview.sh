#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/DesktopPongSettingsPreview.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
SECTION="${1:-appearance}"
RENDER_PATH="$ROOT_DIR/.build/settings-preview-$SECTION.png"

"$ROOT_DIR/script/build_runtime_checks.sh" >/dev/null
rm -rf "$APP_BUNDLE"
cp -R "$ROOT_DIR/.build/DesktopPongRuntimeChecks.app" "$APP_BUNDLE"
plutil -replace CFBundleIdentifier -string com.marcustossmann.DesktopPongSettingsPreview "$INFO_PLIST"
plutil -replace CFBundleName -string "Desktop Pong Settings Preview" "$INFO_PLIST"
plutil -insert LSEnvironment.DESKTOP_PONG_SETTINGS_ONLY -string 1 "$INFO_PLIST"
plutil -insert LSEnvironment.DESKTOP_PONG_SETTINGS_RENDER_PATH -string "$RENDER_PATH" "$INFO_PLIST"
plutil -insert LSEnvironment.DESKTOP_PONG_SETTINGS_SECTION -string "$SECTION" "$INFO_PLIST"
rm -f "$RENDER_PATH"

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
echo "$APP_BUNDLE"
