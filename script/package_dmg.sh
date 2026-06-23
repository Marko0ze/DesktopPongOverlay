#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DesktopPongOverlay.app"
DMG_PATH="$ROOT_DIR/dist/DesktopPongOverlay-0.1.0.dmg"
VOL_NAME="Desktop Pong Overlay"

usage() {
  cat >&2 <<'USAGE'
usage: ./script/package_dmg.sh [--local|--developer-id|--notarize]

Modes:
  --local         Create an ad-hoc-signed local test DMG. Default.
  --developer-id Create a Developer ID signed DMG. Requires a valid
                 Developer ID Application identity in the keychain, or
                 DEVELOPER_ID_APPLICATION set to the identity name/hash.
  --notarize     Developer ID sign, submit DMG to Apple notary service,
                 staple the ticket, and verify Gatekeeper assessment.

Notarization credentials:
  Prefer NOTARYTOOL_PROFILE for an existing notarytool keychain profile.
  Alternatively set APPLE_ID, APPLE_TEAM_ID, and APP_SPECIFIC_PASSWORD.
USAGE
}

case "$MODE" in
  --local|local)
    MODE="local"
    ;;
  --developer-id|developer-id)
    MODE="developer-id"
    ;;
  --notarize|notarize)
    MODE="notarize"
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

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Build the app first with ./script/build_and_run.sh --build" >&2
  exit 1
fi

developer_id_identity() {
  if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "$DEVELOPER_ID_APPLICATION"
    return
  fi

  identities=()
  while IFS= read -r identity; do
    identities+=("$identity")
  done < <(
    /usr/bin/security find-identity -v -p codesigning |
      /usr/bin/awk -F '"' '/Developer ID Application/ { print $2 }'
  )

  case "${#identities[@]}" in
    0)
      echo "No Developer ID Application signing identity found." >&2
      echo "Install the certificate or set DEVELOPER_ID_APPLICATION to a valid identity." >&2
      exit 1
      ;;
    1)
      echo "${identities[0]}"
      ;;
    *)
      echo "Multiple Developer ID Application identities found." >&2
      echo "Set DEVELOPER_ID_APPLICATION to the identity name or hash to choose one." >&2
      exit 1
      ;;
  esac
}

sign_app() {
  if [[ "$MODE" == "local" ]]; then
    /usr/bin/codesign --force --deep --options runtime --sign - "$APP_BUNDLE"
  else
    local identity="$1"
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$identity" "$APP_BUNDLE"
  fi
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

sign_dmg() {
  if [[ "$MODE" == "local" ]]; then
    /usr/bin/codesign --force --sign - "$DMG_PATH"
  else
    local identity="$1"
    /usr/bin/codesign --force --timestamp --sign "$identity" "$DMG_PATH"
  fi
  /usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
}

notarize_dmg() {
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "Notarization credentials are missing." >&2
    echo "Set NOTARYTOOL_PROFILE, or APPLE_ID + APPLE_TEAM_ID + APP_SPECIFIC_PASSWORD." >&2
    exit 1
  fi

  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/sbin/spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
}

SIGNING_IDENTITY=""
if [[ "$MODE" != "local" ]]; then
  SIGNING_IDENTITY="$(developer_id_identity)"
fi

sign_app "$SIGNING_IDENTITY"
/usr/bin/hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

sign_dmg "$SIGNING_IDENTITY"

if [[ "$MODE" == "notarize" ]]; then
  notarize_dmg
fi

echo "$DMG_PATH"
