#!/bin/bash
# desktop/scripts/build-dmg.sh
# Build and package Poke Desktop as a DMG

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="PokeDesktop"
BUILD_DIR="build"
APP_NAME="Poke Desktop.app"
DMG_NAME="PokeDesktop.dmg"

echo "Building $SCHEME..."
xcodebuild -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    archive

echo "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "$BUILD_DIR/export"

echo "Creating DMG..."
hdiutil create -volname "Poke Desktop" \
    -srcfolder "$BUILD_DIR/export/$APP_NAME" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

echo "Done: $BUILD_DIR/$DMG_NAME"
