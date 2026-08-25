#!/usr/bin/env bash
# Build a drag-to-install DMG for Lights.
set -euo pipefail

cd "$(dirname "$0")"

APP="Lights.app"
DIST="dist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG="$DIST/Codex-Traffic-Light-v$VERSION.dmg"
mkdir -p "$DIST"
RW_DMG=$(mktemp "$DIST/.Codex-Traffic-Light.XXXXXX.dmg")
rm -f "$RW_DMG"
VOLUME_NAME="Codex Traffic Light"
DEVICE=""

cleanup() {
    if [ -n "$DEVICE" ]; then
        hdiutil detach "$DEVICE" -quiet || true
    fi
    rm -f "$RW_DMG"
}
trap cleanup EXIT

echo "→ Building app bundle..."
./build-app.sh

echo "→ Preparing drag-to-install disk image..."
rm -f "$DMG"
hdiutil create -size 30m -fs HFS+ -volname "$VOLUME_NAME" "$RW_DMG" >/dev/null
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/^\/dev\/disk/{ print $1; exit }')
VOLUME="/Volumes/$VOLUME_NAME"

ditto "$APP" "$VOLUME/$APP"
ln -s /Applications "$VOLUME/Applications"
mkdir -p "$VOLUME/.background"
swift tools/render-dmg-background.swift "$VOLUME/.background/background.png"
chflags hidden "$VOLUME/.background"

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 820, 560}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Applications" to {180, 240}
        set position of item "$APP" to {540, 240}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" >/dev/null

echo "✓ Done: $DMG"
echo "  Open it and drag Lights.app to Applications."
