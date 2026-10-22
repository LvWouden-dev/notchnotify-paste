#!/bin/bash
# Builds, signs, notarizes and publishes NotchNotify Paste as a GitHub release.
# The asset name never changes, so this link always serves the newest version:
#   https://github.com/<owner>/<repo>/releases/latest/download/NotchNotifyPaste.dmg
#
# Usage:  ./release.sh 1.1 "What changed in this version"
# Finds your Developer ID certificate and this GitHub repository by itself; optional overrides:
#   NOTCH_SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTCH_NOTARY_PROFILE  name used with `xcrun notarytool store-credentials`
#   NOTCH_GITHUB_REPO     e.g. "yourname/notchnotify-paste"
# Not tested yet.
set -euo pipefail

VERSION="${1:?Pass a version, e.g. ./release.sh 1.1 \"Notes\"}"
NOTES="${2:-NotchNotify Paste $VERSION}"
cd "$(dirname "$0")"

# Signing identity: from the environment, or the first valid Developer ID Application certificate.
find_identity() {
    security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1
}
IDENTITY="${NOTCH_SIGN_IDENTITY:-$(find_identity)}"

if [ -z "$IDENTITY" ] && security find-certificate -c "Developer ID Application" >/dev/null 2>&1; then
    # The certificate is there but not trusted: almost always Apple's intermediate certificate is missing.
    echo "Found a Developer ID certificate that macOS doesn't trust yet. Installing Apple's intermediate certificate…"
    TMP_CER="$(mktemp -d)/DeveloperIDG2CA.cer"
    if curl -fsSL -o "$TMP_CER" "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer"; then
        security import "$TMP_CER" -k "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1 || true
    fi
    IDENTITY="$(find_identity)"
fi

if [ -z "$IDENTITY" ]; then
    echo "" >&2
    echo "Can't sign: this Mac has no usable 'Developer ID Application' certificate." >&2
    echo "What this Mac has:" >&2
    security find-identity -v -p codesigning >&2 || true
    echo "" >&2
    if security find-certificate -c "Developer ID Application" >/dev/null 2>&1; then
        echo "A Developer ID certificate exists but without its private key (made on another Mac)." >&2
        echo "Fix: create a new one on this Mac (below), or export it as .p12 from the other Mac." >&2
    fi
    echo "Fix: Xcode > Settings > Accounts > select your team > Manage Certificates > + > Developer ID Application." >&2
    echo "(Only the team's Account Holder can create it; then run this script again.)" >&2
    exit 1
fi
TEAM_ID="$(echo "$IDENTITY" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')"
echo "Signing as: $IDENTITY"

# GitHub repository: from the environment, or this folder's own repository.
REPO="${NOTCH_GITHUB_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

# Notarization login (stored once in the keychain; asks for it the first time).
PROFILE="${NOTCH_NOTARY_PROFILE:-notchnotify}"
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "First time: saving your notarization login (Apple ID + app-specific password from account.apple.com)."
    read -r -p "Apple ID email: " APPLE_ID
    xcrun notarytool store-credentials "$PROFILE" --apple-id "$APPLE_ID" --team-id "$TEAM_ID"
fi

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release v$VERSION already exists. Use a higher version." >&2
    exit 1
fi

# 1. Build and sign
VERSION="$VERSION" bash ./build.sh "$IDENTITY"

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
