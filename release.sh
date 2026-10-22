#!/bin/bash
# Builds, signs, notarizes and publishes NotchNotify Paste as a GitHub release.
# The asset name never changes, so this link always serves the newest version:
#   https://github.com/<owner>/<repo>/releases/latest/download/NotchNotifyPaste.dmg
#
# Usage:  ./release.sh 1.1 "What changed in this version"
# Needs (once, see RELEASING.md):
#   NOTCH_SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTCH_NOTARY_PROFILE  name used with `xcrun notarytool store-credentials`
#   NOTCH_GITHUB_REPO     e.g. "yourname/notchnotify-paste"
# Not tested yet.
set -euo pipefail

VERSION="${1:?Pass a version, e.g. ./release.sh 1.1 \"Notes\"}"
NOTES="${2:-NotchNotify Paste $VERSION}"
IDENTITY="${NOTCH_SIGN_IDENTITY:?Set NOTCH_SIGN_IDENTITY}"
PROFILE="${NOTCH_NOTARY_PROFILE:?Set NOTCH_NOTARY_PROFILE}"
REPO="${NOTCH_GITHUB_REPO:?Set NOTCH_GITHUB_REPO}"
cd "$(dirname "$0")"

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release v$VERSION already exists. Use a higher version." >&2
    exit 1
fi

# 1. Build and sign
VERSION="$VERSION" ./build.sh "$IDENTITY"

# 2. Notarize, then staple the ticket to the app so it opens offline too
xcrun notarytool submit build/NotchNotifyPaste.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple "build/NotchNotify Paste.app"
xcrun stapler validate "build/NotchNotify Paste.app"

# 3. A drag-to-Applications disk image with the stapled app, itself signed, notarized and stapled
DMG="build/NotchNotifyPaste.dmg"
rm -rf build/dmg "$DMG" && mkdir -p build/dmg
cp -R "build/NotchNotify Paste.app" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "NotchNotify Paste" -srcfolder build/dmg -ov -format UDZO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
(cd build && shasum -a 256 NotchNotifyPaste.dmg > NotchNotifyPaste.dmg.sha256)

# 4. Publish (creates the tag on the repo's default branch and marks it as latest)
gh release create "v$VERSION" \
    "$DMG" build/NotchNotifyPaste.dmg.sha256 \
    --repo "$REPO" --title "NotchNotify Paste $VERSION" --notes "$NOTES" --latest

echo "Published: https://github.com/$REPO/releases/latest/download/NotchNotifyPaste.dmg"
