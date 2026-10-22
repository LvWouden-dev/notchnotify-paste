# Releasing NotchNotify Paste

One-time setup:

1. A "Developer ID Application" certificate (Xcode › Settings › Accounts › Manage Certificates › +).
2. `xcrun notarytool store-credentials notchnotify --apple-id <you> --team-id <TEAMID>` (app-specific password).
3. `brew install gh` and `gh auth login`.
4. In `~/.zshrc`:
   ```
   export NOTCH_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
   export NOTCH_NOTARY_PROFILE="notchnotify"
   export NOTCH_GITHUB_REPO="yourname/notchnotify-paste"
   ```

Each release: `./release.sh 1.1 "What changed"`

This builds, signs, notarizes and staples a drag-to-Applications disk image and publishes it as the latest GitHub release. The download link stays the same for every version:
`https://github.com/<repo>/releases/latest/download/NotchNotifyPaste.dmg`
