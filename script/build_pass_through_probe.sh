#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/DesktopPongPassThroughProbe.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
REPORT_PATH="$ROOT_DIR/.build/pass-through-probe-count.txt"

"$ROOT_DIR/script/build_runtime_checks.sh" >/dev/null
rm -rf "$APP_BUNDLE"
cp -R "$ROOT_DIR/.build/DesktopPongRuntimeChecks.app" "$APP_BUNDLE"
plutil -replace CFBundleIdentifier -string com.marcustossmann.DesktopPongPassThroughProbe "$INFO_PLIST"
plutil -replace CFBundleName -string "Desktop Pong Pass-through Probe" "$INFO_PLIST"
plutil -insert LSEnvironment.DESKTOP_PONG_PASS_THROUGH_PROBE -string 1 "$INFO_PLIST"
plutil -insert LSEnvironment.DESKTOP_PONG_PROBE_REPORT -string "$REPORT_PATH" "$INFO_PLIST"
printf '0' >"$REPORT_PATH"

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
echo "$APP_BUNDLE"
