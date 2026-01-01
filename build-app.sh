#!/bin/bash

set -e

APP_NAME="DevManager"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building release..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 复制可执行文件
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# 复制 Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# 复制资源文件
cp Sources/DevManager/Resources/*.png "$RESOURCES_DIR/" 2>/dev/null || true

echo "✅ App bundle created: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "To create DMG:"
echo "  hdiutil create -volname \"$APP_NAME\" -srcfolder \"$APP_BUNDLE\" -ov -format UDZO \"$APP_NAME.dmg\""
