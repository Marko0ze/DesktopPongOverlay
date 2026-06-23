#!/usr/bin/env bash
set -euo pipefail

# Tahoe 26.5.1 Command Line Tools currently ship a Swift compiler whose patch
# build identifier is newer than the bundled SDK interface. Matching the SDK's
# public compiler version keeps manifest compilation working until Xcode 26 is
# installed or the Command Line Tools package is refreshed.
exec /Library/Developer/CommandLineTools/usr/bin/swiftc \
  -Xfrontend -interface-compiler-version \
  -Xfrontend 6.3.2 \
  "$@"
