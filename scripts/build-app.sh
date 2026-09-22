#!/bin/bash
# Builds Rayvy.app from the Swift package for local use or GitHub Releases distribution.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Rayvy"
BUILD_CONFIG="release"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "==> swift build -c $BUILD_CONFIG"
swift build -c "$BUILD_CONFIG" --arch arm64

BIN_PATH=$(swift build -c "$BUILD_CONFIG" --arch arm64 --show-bin-path)

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Set by release.yml from the pushed tag; left as the Info.plist default for local builds.
if [ -n "${VERSION:-}" ]; then
	echo "==> Setting CFBundleShortVersionString to $VERSION"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
fi

if [ -f "Resources/AppIcon.icns" ]; then
	cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Built $APP_BUNDLE"
