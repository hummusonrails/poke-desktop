#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

VERSION="${1:-1.0.0}"
RELEASE_DIR="build/release"
TARBALL="build/PokeDesktop-${VERSION}-macOS.tar.gz"

echo "Building Poke Desktop v${VERSION}..."

# Build release
xcodegen generate
xcodebuild -scheme PokeDesktop -configuration Release build -derivedDataPath build -quiet

echo "Packaging release..."

# Create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Copy app bundle
cp -R build/Build/Products/Release/PokeDesktop.app "$RELEASE_DIR/"

# Copy install script
cp scripts/install.sh "$RELEASE_DIR/"

# Create tarball
cd build
tar -czf "../$TARBALL" -C release .
cd ..

echo ""
echo "Release tarball: $TARBALL"
echo "Size: $(du -h "$TARBALL" | cut -f1)"
echo ""
echo "To install on another Mac:"
echo "  tar xzf PokeDesktop-${VERSION}-macOS.tar.gz"
echo "  ./install.sh"
