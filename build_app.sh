#!/usr/bin/env bash
# Build a release binary, wrap it in Pomodoro.app (menu bar only, no Dock icon),
# and install it in /Applications so Spotlight opens the latest build.
set -euo pipefail
cd "$(dirname "$0")"

APP=Pomodoro.app
DEST="/Applications/$APP"
BUNDLE_ID=com.namatran.Pomodoro
# Sparkle compares CFBundleVersion, so it must only go up: the commit count does.
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD)"
FEED_URL=https://pomodoro-web-black.vercel.app/appcast.xml
# The EdDSA public key that updates must be signed with. The private key stays in the login Keychain.
if [ ! -s sparkle-public-key ]; then
    echo "No sparkle-public-key. Run generate_keys from Sparkle's tools and save the key it prints there." >&2
    exit 1
fi
PUBLIC_KEY="$(tr -d '[:space:]' < sparkle-public-key)"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/Pomodoro"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"
# Sparkle comes signed by its developers; ditto keeps its symlinks, so that signature stays valid.
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Pomodoro"

# The icon is the drawn tomato, rendered by the app itself and scaled to every size macOS wants.
# Run the bundled copy: only it can find Sparkle.framework, through the rpath added above.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
"$APP/Contents/MacOS/Pomodoro" --render-icon "$ICONSET/icon_512x512@2x.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    # 512@2x is the 1024px render itself.
    if [ $size -lt 512 ]; then
        sips -z $((size * 2)) $((size * 2)) "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    fi
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pomodoro</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.namatran.Pomodoro</string>
    <key>CFBundleName</key>
    <string>Pomodoro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>$FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will deliver notifications to the app. No --deep: Sparkle keeps its own signature.
codesign --force --sign - "$APP"

running() {
    osascript -e "application id \"$BUNDLE_ID\" is running" | grep -q true
}

# A real Quit, not a kill, so the running copy saves an unsaved run first.
if running; then
    osascript -e "tell application id \"$BUNDLE_ID\" to quit"
    while running; do sleep 0.2; done
fi

rm -rf "$DEST"
ditto "$APP" "$DEST"
# Only the installed copy is kept, so Spotlight doesn't list two.
rm -rf "$APP"
open "$DEST"

echo "Installed and opened $DEST ($VERSION, build $BUILD)"
