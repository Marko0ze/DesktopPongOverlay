#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${1:-desktop-pong-notary}"

usage() {
  cat >&2 <<'USAGE'
usage: ./script/store_notary_profile.sh [profile-name]

Stores an Apple notarytool keychain profile for later:

  NOTARYTOOL_PROFILE="desktop-pong-notary" ./script/package_dmg.sh --notarize

For the smoothest non-interactive setup, export APPLE_ID and APPLE_TEAM_ID
before running this script. notarytool will prompt securely for the app-specific
password when needed.

This script intentionally does not accept or echo an app-specific password.
USAGE
}

case "$PROFILE_NAME" in
  --help|-h|help)
    usage
    exit 0
    ;;
esac

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  /usr/bin/xcrun notarytool store-credentials "$PROFILE_NAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --validate
else
  /usr/bin/xcrun notarytool store-credentials "$PROFILE_NAME" --validate
fi

echo "Stored notarytool profile: $PROFILE_NAME"
