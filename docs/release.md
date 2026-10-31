# Release

Smoll Notch is not in the Mac App Store: it runs without the App Sandbox and reads Now Playing through
a private framework (see README). It ships as a Developer ID signed, notarized DMG, for example as a
GitHub Release.

## One-time setup

1. **Developer ID certificate** (personal team `2567P974L9`, never the INNIO team):
   Xcode › Settings › Accounts › your Apple ID › team 2567P974L9 › Manage Certificates › + ›
   **Developer ID Application**. Check with:
   ```
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
2. **App-specific password** for notarization: account.apple.com › Sign-In and Security ›
   App-Specific Passwords. Name it "notarytool".
3. **Store the notarization credentials** in the keychain (never in the repo):
   ```
   xcrun notarytool store-credentials smoll-notch --apple-id <apple-id> --team-id 2567P974L9
   ```
   It asks for the app-specific password. The profile name `smoll-notch` is what `scripts/release.sh`
   expects (override with `NOTARY_PROFILE=...`).

## Every release

1. Bump the version in `project.yml`: `MARKETING_VERSION` for user-visible changes,
   `CURRENT_PROJECT_VERSION` (build number) always.
2. Run the release script:
   ```
   scripts/release.sh
   ```
   It generates the project, runs the tests, archives a universal Release build, exports it with
   Developer ID, builds the DMG (with a link to Programme), notarizes, staples and checks Gatekeeper.
   The result is `build/release/SmollNotch-<version>.dmg`.
3. Smoke test on this Mac: open the DMG, drag the app to Programme, start it, play something in
   Music, in Safari (YouTube) and in Spotify. Hover, controls and seeking work, the settings open
   from the menu bar.
4. Commit the version bump, tag and publish:
   ```
   git tag v<version> && git push origin v<version>
   gh release create v<version> build/release/SmollNotch-<version>.dmg --title "Smoll Notch <version>" --notes "..."
   ```

`scripts/release.sh --skip-notarize` skips notarization for a quick local check. That DMG only opens
without a Gatekeeper warning on this Mac.

## After macOS updates

Apple can close the MediaRemote workaround with any macOS update. After updating macOS, check that
the adapter still answers (with something playing):
```
APP=/Applications/SmollNotch.app/Contents
/usr/bin/perl $APP/Resources/mediaremote-adapter.pl $APP/Frameworks/MediaRemoteAdapter.framework get --no-artwork
```
If it prints nothing or fails, look for an update of
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), update `Vendor/MediaRemoteAdapter`
(keep the patch in `PATCHES.md`) and release again.

## Checklist

- [ ] Version and build number bumped in `project.yml`
- [ ] Tests green (the script runs them)
- [ ] DMG notarized and stapled (`spctl` says "accepted, source=Notarized Developer ID")
- [ ] Smoke test with Music, Safari and Spotify
- [ ] Privacy policy current (`docs/datenschutz.md`), `PrivacyInfo.xcprivacy` unchanged unless data use changed
- [ ] Tag pushed, GitHub Release with DMG
