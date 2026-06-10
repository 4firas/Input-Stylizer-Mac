#!/bin/bash
set -e

# Change directory to script's location
cd "$(dirname "$0")"

echo "🧹 Cleaning previous builds..."
rm -rf SystemWideStylizer.app
rm -rf .build

echo "🔨 Building SystemWideStylizer in release mode..."
swift build -c release

echo "📦 Packaging SystemWideStylizer.app bundle..."
APP_DIR="SystemWideStylizer.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

# Recreate the bundle structure
mkdir -p "$MACOS_DIR"

# Copy compiled binary and Info.plist
cp .build/release/SystemWideStylizer "$MACOS_DIR/"
cp Sources/SystemWideStylizer/Info.plist "$CONTENTS_DIR/"

# Make the executable executable
chmod +x "$MACOS_DIR/SystemWideStylizer"

# On macOS (especially Apple Silicon), ad-hoc signing is critical for accessibility TCC database registration
echo "✍️ Signing application..."
codesign -s - --force --deep "$APP_DIR"

echo "🚀 Launching SystemWideStylizer.app..."
open "$APP_DIR"

echo "✅ Done! If this is the first time running, macOS will now prompt you for Accessibility permissions for SystemWideStylizer."
echo "   Go to System Settings -> Privacy & Security -> Accessibility and turn it ON."
