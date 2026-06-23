#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DesktopPongOverlay.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/DesktopPongOverlay"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
DMG_PATH="$ROOT_DIR/dist/DesktopPongOverlay-0.1.0.dmg"
TMP_OUTPUT="$(/usr/bin/mktemp -t desktop-pong-preflight.XXXXXX)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

usage() {
  cat >&2 <<'USAGE'
usage: ./script/release_preflight.sh [--local|--distribution]

  --local         Verify the staged local app/DMG artifacts.
  --distribution Verify local artifacts plus Developer ID/notary prerequisites.
USAGE
}

case "$MODE" in
  --local|local)
    MODE="local"
    ;;
  --distribution|distribution)
    MODE="distribution"
    ;;
  --help|-h|help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

failures=0

check() {
  local title="$1"
  shift
  if "$@" >"$TMP_OUTPUT" 2>&1; then
    echo "PASS: $title"
  else
    echo "FAIL: $title"
    sed 's/^/  /' "$TMP_OUTPUT"
    failures=$((failures + 1))
  fi
}

check_exists() {
  local title="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $title"
  else
    echo "FAIL: $title"
    echo "  Missing: $path"
    failures=$((failures + 1))
  fi
}

check_contains() {
  local title="$1"
  local expected="$2"
  shift 2
  if "$@" >"$TMP_OUTPUT" 2>&1 &&
     /usr/bin/grep -q "$expected" "$TMP_OUTPUT"; then
    echo "PASS: $title"
  else
    echo "FAIL: $title"
    sed 's/^/  /' "$TMP_OUTPUT"
    failures=$((failures + 1))
  fi
}

check_exists "app bundle exists" "$APP_BUNDLE"
check_exists "app binary exists" "$APP_BINARY"
check_exists "Info.plist exists" "$INFO_PLIST"
check_exists "DMG exists" "$DMG_PATH"

if [[ -e "$INFO_PLIST" ]]; then
  check "Info.plist is valid" /usr/bin/plutil -lint "$INFO_PLIST"
  check_contains "minimum macOS target is 26.0" "26.0" /usr/bin/plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST"
fi

if [[ -e "$APP_BINARY" ]]; then
  check_contains "binary includes arm64" "arm64" /usr/bin/lipo -info "$APP_BINARY"
  check_contains "binary includes x86_64" "x86_64" /usr/bin/lipo -info "$APP_BINARY"
fi

if [[ -e "$APP_BUNDLE" ]]; then
  check "app code signature verifies" /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  check_contains "app signature has hardened runtime" "runtime" /usr/bin/codesign -dvvv "$APP_BUNDLE"
fi

if [[ -e "$DMG_PATH" ]]; then
  check "DMG code signature verifies" /usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$MODE" == "distribution" ]]; then
  check "notarytool is installed" /usr/bin/xcrun notarytool --version

  if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    if /usr/bin/security find-identity -v -p codesigning |
       /usr/bin/grep -F "Developer ID Application" |
       /usr/bin/grep -Fq "$DEVELOPER_ID_APPLICATION"; then
      echo "PASS: configured Developer ID identity is installed"
    else
      echo "FAIL: configured Developer ID identity is installed"
      echo "  DEVELOPER_ID_APPLICATION did not match an installed Developer ID Application identity."
      failures=$((failures + 1))
    fi
  else
    identity_count="$(
      /usr/bin/security find-identity -v -p codesigning |
        /usr/bin/awk -F '"' '/Developer ID Application/ { count += 1 } END { print count + 0 }'
    )"
    if [[ "$identity_count" == "1" ]]; then
      echo "PASS: exactly one Developer ID Application identity is installed"
    elif [[ "$identity_count" == "0" ]]; then
      echo "FAIL: Developer ID Application identity is installed"
      echo "  No Developer ID Application signing identity found."
      failures=$((failures + 1))
    else
      echo "FAIL: Developer ID Application identity is unambiguous"
      echo "  Found $identity_count identities. Set DEVELOPER_ID_APPLICATION to choose one."
      failures=$((failures + 1))
    fi
  fi

  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "PASS: NOTARYTOOL_PROFILE is set"
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "PASS: Apple ID notarization environment is set"
  else
    echo "FAIL: notarization credentials are configured"
    echo "  Set NOTARYTOOL_PROFILE, or APPLE_ID + APPLE_TEAM_ID + APP_SPECIFIC_PASSWORD."
    failures=$((failures + 1))
  fi
fi

if (( failures > 0 )); then
  echo "Release preflight failed ($failures issue(s))."
  exit 1
fi

echo "Release preflight passed."
