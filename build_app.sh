#!/usr/bin/env bash
# Build a release binary and wrap it in Pomodoro.app (menu bar only, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")"

APP=Pomodoro.app

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pomodoro"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"

# The icon is the drawn tomato, rendered by the app itself and scaled to every size macOS wants.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
"$BIN" --render-icon "$ICONSET/icon_512x512@2x.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    # 512@2x is the 1024px render itself.
    if [ $size -lt 512 ]; then
        sips -z $((size * 2)) $((size * 2)) "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    fi
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will deliver notifications to the app.
codesign --force --sign - "$APP"

echo "Built $APP. Run: open $APP"
