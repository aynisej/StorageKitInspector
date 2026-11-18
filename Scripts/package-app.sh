#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
EXECUTABLE_PATH="$BUILD_DIR/StorageKitInspector"
APP_DIR="$ROOT_DIR/dist/StorageKitInspector.app"
ARCHIVE_PATH="$ROOT_DIR/dist/StorageKitInspector-macOS-arm64.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="1.0.0"

mkdir -p "$BUILD_DIR" "$ROOT_DIR/dist"
swiftc -O "$ROOT_DIR/StorageKitInspector/main.swift" \
    -target arm64-apple-macosx14.0 \
    -framework AppKit \
    -o "$EXECUTABLE_PATH"

rm -rf "$APP_DIR" "$ARCHIVE_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/StorageKitInspector"
chmod +x "$MACOS_DIR/StorageKitInspector"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>StorageKitInspector</string>
    <key>CFBundleIdentifier</key>
    <string>dev.local.StorageKitInspector</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>StorageKitInspector</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"

echo "Created $APP_DIR"
echo "Created $ARCHIVE_PATH"
