#!/bin/bash
# Builds NotchNotify Paste.app, signs it with a Developer ID certificate, and zips it for hosting.
# Notarization is a separate step (see README.md). Not tested yet.
#
# Usage: ./build.sh "Developer ID Application: Your Name (TEAMID)"
set -euo pipefail

IDENTITY="${1:?Pass your Developer ID Application identity}"
BUNDLE_ID="com.notchnotify.paste"     # must match PasteCompanion.bundleID in NotchNotify
VERSION="${VERSION:-1.0}"                # release.sh passes this in
BUILD_NUMBER="$(date +%Y%m%d%H%M)"       # always increases, so macOS sees updates as newer
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/NotchNotifyPaste"

APP="build/NotchNotify Paste.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/NotchNotifyPaste"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>NotchNotify Paste</string>
    <key>CFBundleExecutable</key><string>NotchNotifyPaste</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
ditto -c -k --keepParent "$APP" "build/NotchNotifyPaste.zip"
echo "Built build/NotchNotifyPaste.zip. Next: notarize and staple (README.md)."
