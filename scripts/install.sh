#!/bin/bash
set -e

APP_NAME="Poke Desktop"
APP_DIR="/Applications/Poke Desktop.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing $APP_NAME..."

# Kill existing instance
pkill -f "PokeDesktop" 2>/dev/null || true
sleep 1

# Check if we have a pre-built app in the release bundle
if [ -d "$SCRIPT_DIR/PokeDesktop.app" ]; then
    echo "  Using pre-built app..."
    rm -rf "$APP_DIR"
    cp -R "$SCRIPT_DIR/PokeDesktop.app" "$APP_DIR"
elif [ -f "$SCRIPT_DIR/../project.yml" ]; then
    echo "  Building from source..."
    cd "$SCRIPT_DIR/.."

    # Check for xcodegen
    if ! command -v xcodegen &>/dev/null; then
        echo "Error: xcodegen is required. Install with: brew install xcodegen"
        exit 1
    fi

    # Check for xcodebuild
    if ! command -v xcodebuild &>/dev/null; then
        echo "Error: Xcode is required. Install from the Mac App Store."
        exit 1
    fi

    xcodegen generate
    xcodebuild -scheme PokeDesktop -configuration Release build -derivedDataPath build -quiet
    rm -rf "$APP_DIR"
    cp -R build/Build/Products/Release/PokeDesktop.app "$APP_DIR"
else
    echo "Error: No app bundle or source found."
    exit 1
fi

# Strip quarantine attribute (fixes "app is damaged" error for unsigned apps)
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "  Installed to $APP_DIR"

# Grant Full Disk Access reminder
echo ""
echo "IMPORTANT: You need to grant permissions manually:"
echo "  1. System Settings > Privacy & Security > Full Disk Access"
echo "     → Add /Applications/Poke Desktop.app"
echo "  2. Microphone and Speech Recognition permissions will be"
echo "     requested on first use."
echo ""

# Launch
open "$APP_DIR"
echo "Done! $APP_NAME is running in your menu bar."
