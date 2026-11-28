#!/usr/bin/env bash
# Publish a new version: build and install it, zip it into the website, sign the zip with
# Sparkle's key and add it to the website's appcast, so installed copies offer the update.
# Usage: ./release.sh ["Release notes, as one line of text or HTML"]
# Bump VERSION and commit first. This commits nothing; the website is committed and pushed by hand.
set -euo pipefail
cd "$(dirname "$0")"

WEB="${WEB_DIR:-../pomodoro-web}"
SITE=https://pomodoro-web-black.vercel.app
APP=/Applications/Pomodoro.app
NOTES="${1:-}"

[ -d "$WEB/public" ] || { echo "No website at $WEB. Set WEB_DIR." >&2; exit 1; }
# The build number is the commit count, so uncommitted changes would ship under an old number.
if [ -n "$(git status --porcelain)" ]; then
    echo "Commit your changes first; the build number comes from the commit count." >&2
    exit 1
fi

VERSION="$(cat VERSION)"
APPCAST="$WEB/feed/appcast.xml"
if [ -f "$APPCAST" ] && grep -q "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$APPCAST"; then
    echo "$VERSION is already in the appcast. Bump VERSION first." >&2
    exit 1
fi

# SwiftPM puts Sparkle's tools under .build/artifacts, or .build/index-build/artifacts when the editor fetched it.
# bin/old_dsa_scripts has an older sign_update, so match the exact path.
SIGN_UPDATE="$(find .build -path '*/artifacts/sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1)"
[ -n "$SIGN_UPDATE" ] || { echo "No sign_update. Run swift package resolve first." >&2; exit 1; }

./build_app.sh

# Read what was actually built, not what we meant to build.
PLIST="$APP/Contents/Info.plist"
SHORT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/Pomodoro")"

# One zip per version, so the appcast's older entries keep working, plus PomodoroBar.zip
# as the landing page's always-latest download.
ZIP_NAME="Pomodoro-$SHORT.zip"
DOWNLOADS="$WEB/public/downloads"
mkdir -p "$DOWNLOADS"
rm -f "$DOWNLOADS/$ZIP_NAME"
ditto -c -k --keepParent "$APP" "$DOWNLOADS/$ZIP_NAME"
cp "$DOWNLOADS/$ZIP_NAME" "$DOWNLOADS/PomodoroBar.zip"

# Prints: sparkle:edSignature="..." length="..."
SIGNATURE="$("$SIGN_UPDATE" "$DOWNLOADS/$ZIP_NAME")"

APPCAST="$APPCAST" SHORT="$SHORT" BUILD="$BUILD" MIN_OS="$MIN_OS" NOTES="$NOTES" \
URL="$SITE/downloads/$ZIP_NAME" SIGNATURE="$SIGNATURE" /usr/bin/python3 -I - <<'PY'
import os
from email.utils import formatdate

e = os.environ
path = e["APPCAST"]
marker = "<!-- Newest release first. release.sh adds items here. -->"
if not os.path.exists(path):
    with open(path, "w") as f:
        f.write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Pomodoro Bar</title>
    {marker}
  </channel>
</rss>
""")
notes = f"\n      <description><![CDATA[{e['NOTES']}]]></description>" if e["NOTES"] else ""
item = f"""{marker}
    <item>
      <title>Version {e['SHORT']}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{e['BUILD']}</sparkle:version>
      <sparkle:shortVersionString>{e['SHORT']}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{e['MIN_OS']}</sparkle:minimumSystemVersion>{notes}
      <enclosure url="{e['URL']}" {e['SIGNATURE']} type="application/octet-stream"/>
    </item>"""
with open(path) as f:
    text = f.read()
if marker not in text:
    raise SystemExit(f"No marker in {path}; add this line inside <channel>: {marker}")
with open(path, "w") as f:
    f.write(text.replace(marker, item, 1))
PY

# The landing page's version line.
sed -i '' "s/version: \"[^\"]*\"/version: \"$SHORT\"/" "$WEB/lib/release.ts"

echo
echo "Released $SHORT (build $BUILD, $ARCHS) into $WEB:"
echo "  public/downloads/$ZIP_NAME, public/downloads/PomodoroBar.zip, feed/appcast.xml, lib/release.ts"
echo "Check lib/release.ts still says the right macOS and chip, then commit and push the website."
