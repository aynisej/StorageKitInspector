#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/StorageKitInspector.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/.build/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/Release"
EXECUTABLE_PATH="$PRODUCTS_DIR/StorageKitInspector"
APP_DIR="$ROOT_DIR/dist/StorageKitInspector.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme StorageKitInspector \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

rm -rf "$APP_DIR"
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Created $APP_DIR"
