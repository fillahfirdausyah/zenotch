#!/usr/bin/env bash
# Builds a universal release zip and checksum into build/: scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>}"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
[[ "$VERSION" == "$PLIST_VERSION" ]] || { echo "Info.plist says $PLIST_VERSION, not $VERSION" >&2; exit 1; }

CONFIG=release UNIVERSAL=1 scripts/bundle.sh
cd build
rm -f "Zenotch-$VERSION.zip" "Zenotch-$VERSION.zip.sha256"
ditto -c -k --keepParent Zenotch.app "Zenotch-$VERSION.zip"
shasum -a 256 "Zenotch-$VERSION.zip" > "Zenotch-$VERSION.zip.sha256"
cat "Zenotch-$VERSION.zip.sha256"
