#!/usr/bin/env bash
# Build a release binary and wrap it in Pomodoro.app (menu bar only, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")"

APP=Pomodoro.app

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pomodoro"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pomodoro</string>
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
