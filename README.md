# Smoll Notch

A tiny Dynamic Island for the MacBook notch that shows what is playing right now: Apple Music, Spotify, YouTube in Safari or Chrome, podcasts, anything that appears under "Now Playing" in Control Center.

- **Compact:** artwork left of the notch, an equalizer tinted with the cover color right of it (the signature element).
- **Expanded on hover:** artwork, title, album, artist, previous / play-pause / next and a seekable progress bar. Clicking the artwork brings the source app forward.
- Menu bar only (no Dock icon), settings for launch at login and hiding while paused.
- No backend, no account, nothing leaves the Mac.

## How Now Playing works

Since macOS 15.4 the private MediaRemote framework only answers entitled Apple processes. The app bundles [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3, vendored in `Vendor/MediaRemoteAdapter`, upstream commit in `UPSTREAM_COMMIT`): its framework is loaded into `/usr/bin/perl`, which still has access, and streams JSON lines that `NowPlayingService` folds into `NowPlaying`.

Consequences:
- No App Sandbox and no Mac App Store. Distribution is Developer ID signed and notarized.
- A macOS update can break the adapter. Check with `media-control get` or the adapter's `test` command after updates.

## Project structure

```
SmollNotch/
  App/                 App entry, AppDelegate, launch flags
  Core/Models/         NowPlaying
  Core/Services/       NowPlayingService (adapter process), NowPlayingStream (JSON diff merging)
  Core/Demo/           Demo source for screenshots (Debug only)
  Design/              Island colors, fonts, artwork tint
  Features/Notch/      Island view, view model, shape, window controller
  Features/Settings/   Settings view and view model
Vendor/MediaRemoteAdapter/  Adapter sources, built as an embedded (not linked) framework
SmollNotchTests/       Unit tests (parsing, playback position, tint contrast)
```

## Run

```
cp Config.example.xcconfig Config.xcconfig
xcodegen generate
open SmollNotch.xcodeproj
```

Debug launch flags: `-SmollNotchDemo` (sample tracks), `-SmollNotchExpanded` (always expanded).

Render the island to PNGs without a screen: `SNAPSHOT_DIR=/some/dir xcodebuild test -scheme SmollNotch -only-testing:SmollNotchTests/SnapshotRender`.

## Release

Developer ID signed and notarized DMG via `scripts/release.sh`. Setup and checklist: [docs/release.md](docs/release.md).
