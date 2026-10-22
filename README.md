# NotchNotify Paste (optional helper)

A small menu bar app that presses ⌘V after NotchNotify has dictated text. It exists because the App Store version of NotchNotify is sandboxed and cannot use Accessibility. It is distributed outside the App Store, from your own site.

## How it works

1. NotchNotify copies the dictated text to the clipboard.
2. If this helper is running, NotchNotify posts a notification named `com.notchnotify.paste.request` (no data).
3. The helper presses ⌘V in the frontmost app. It never reads the clipboard.

NotchNotify only checks that the helper is installed and running. It never downloads or launches code that it fetched itself, which is what keeps the App Store version within the rules (guideline 2.5.2). The App Store version opens your download page in the browser; the user installs the helper.

## Publish a new version (one command)

One-time setup:

1. A "Developer ID Application" certificate in your keychain (Xcode > Settings > Accounts > Manage Certificates > +).
2. `xcrun notarytool store-credentials notchnotify --apple-id <you> --team-id <TEAMID>` (uses an app-specific password).
3. `brew install gh`, then `gh auth login`, and create a GitHub repository for the helper.
4. Add to `~/.zshrc`:
   ```
   export NOTCH_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
   export NOTCH_NOTARY_PROFILE="notchnotify"
   export NOTCH_GITHUB_REPO="yourname/notchnotify-paste"
   ```

Each release: `./release.sh 1.1 "What changed"`. The link `https://github.com/<repo>/releases/latest/download/NotchNotifyPaste.zip` then serves the new version.

## Build, sign, notarize by hand

```
./build.sh "Developer ID Application: Your Name (TEAMID)"
xcrun notarytool submit build/NotchNotifyPaste.zip --keychain-profile "<profile>" --wait
xcrun stapler staple "build/NotchNotify Paste.app"
```

Then re-zip the stapled app and host it. Put the page's address in `PasteCompanion.downloadURL` (in the NotchNotify project); until then the Download button stays off.

## Before shipping

- Change `com.notchnotify.paste` to your own bundle identifier, in `build.sh` and in `PasteCompanion.swift`. They must match.
- Untested: nothing here has been built or run. Check that the Accessibility prompt appears, that pasting works in several apps, and that "Open at Login" registers.
- Any process can post the paste notification and trigger a ⌘V of the current clipboard. The impact is low, but decide whether that is acceptable.
- Disclose the helper and its Accessibility use on the download page.
