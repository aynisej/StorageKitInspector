#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
EXECUTABLE_PATH="$BUILD_DIR/StorageKitInspector"
APP_DIR="$ROOT_DIR/dist/StorageKitInspector.app"
ARCHIVE_PATH="$ROOT_DIR/dist/StorageKitInspector-macOS-arm64.zip"
DMG_PATH="$ROOT_DIR/dist/StorageKitInspector-macOS-arm64.dmg"
DMG_STAGE_DIR="$BUILD_DIR/dmg-root"
ICONSET_DIR="$BUILD_DIR/StorageKitInspector.iconset"
ICON_SOURCE="$BUILD_DIR/StorageKitInspector-icon.png"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_PATH="$RESOURCES_DIR/StorageKitInspector.icns"
VERSION="1.0.0"

mkdir -p "$BUILD_DIR" "$ROOT_DIR/dist"
swiftc -O "$ROOT_DIR/StorageKitInspector/main.swift" \
    -target arm64-apple-macosx14.0 \
    -framework AppKit \
    -o "$EXECUTABLE_PATH"

rm -rf "$APP_DIR" "$ARCHIVE_PATH" "$DMG_PATH" "$DMG_STAGE_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/StorageKitInspector"
chmod +x "$MACOS_DIR/StorageKitInspector"

swift "$ROOT_DIR/Scripts/make-icon.swift" "$ICON_SOURCE"
mkdir -p "$ICONSET_DIR"
for spec in '16:icon_16x16' '32:icon_16x16@2x' '32:icon_32x32' '64:icon_32x32@2x' \
            '128:icon_128x128' '256:icon_128x128@2x' '256:icon_256x256' \
            '512:icon_256x256@2x' '512:icon_512x512' '1024:icon_512x512@2x'; do
    size="${spec%%:*}"
    name="${spec#*:}"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"

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
    <key>CFBundleIconFile</key>
    <string>StorageKitInspector</string>
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
mkdir -p "$DMG_STAGE_DIR"
cp -R "$APP_DIR" "$DMG_STAGE_DIR/StorageKitInspector.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
cat > "$DMG_STAGE_DIR/Установка.txt" <<'INSTALL'
Чтобы установить приложение, перетащите StorageKitInspector.app на ярлык Applications.
После копирования извлеките образ и откройте приложение из папки Applications.
INSTALL
hdiutil create \
    -volname "Storage Inspector" \
    -srcfolder "$DMG_STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Created $APP_DIR"
echo "Created $ARCHIVE_PATH"
echo "Created $DMG_PATH"
