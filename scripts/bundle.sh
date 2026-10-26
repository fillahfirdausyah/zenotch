#!/usr/bin/env bash
# Builds build/Zenotch.app without Xcode.
# CONFIG=debug|release (default release). UNIVERSAL=1 builds for Apple silicon and Intel.
# SIGN_IDENTITY overrides ad-hoc signing;
# a stable identity keeps macOS permissions (Calendar, Camera, Accessibility) across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/Zenotch.app"

ARCH_FLAGS=()
CLANG_ARCHS=(-arch "$(uname -m)")
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
  CLANG_ARCHS=(-arch arm64 -arch x86_64)
fi

swift build -c "$CONFIG" --product Zenotch ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Zenotch" "$APP/Contents/MacOS/Zenotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# actool needs Xcode, so build the .icns from the appiconset with iconutil instead.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  for name in "icon_${size}x${size}.png" "icon_${size}x${size}@2x.png"; do
    [[ -f "Resources/AppIcon.appiconset/$name" ]] || { echo "Missing Resources/AppIcon.appiconset/$name" >&2; exit 1; }
    cp "Resources/AppIcon.appiconset/$name" "$ICONSET/"
  done
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cp Resources/MenuBar/ZenotchMenuBarTemplate*.png "$APP/Contents/Resources/"

clang -dynamiclib -fobjc-arc -O2 -Wall "${CLANG_ARCHS[@]}" \
  -framework Foundation \
  -o "$APP/Contents/Resources/libZenotchMediaBridge.dylib" \
  Bridge/MediaRemoteBridge.m

codesign --force --sign "$SIGN_IDENTITY" "$APP/Contents/Resources/libZenotchMediaBridge.dylib"
codesign --force --sign "$SIGN_IDENTITY" "$APP"

# Finder and the Dock cache icons per bundle path; re-register so the new icon shows.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true

echo "Built $APP"
