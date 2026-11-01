import AppKit
import SwiftUI

/// Playback state and actions shared by the islands on all screens.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    /// Changes with every new cover so the view can crossfade it.
    private(set) var artworkID = 0
    /// Icon of the app that plays, shown beside the notch when expanded.
    private(set) var sourceIcon: NSImage?
    private(set) var tint: Color = .islandPrimary
    /// Whether the islands show anything at all (something plays, or is paused and not hidden).
    private(set) var isVisible = false
    /// Briefly true after a track change, so the islands open on their own for a moment.
    private(set) var isPeeking = false
    /// Apple Music favorite state of the current track, nil where it is unknown or unsupported.
    private(set) var isFavorite: Bool?

    private let source: NowPlayingSource
    private let favorites: FavoriteService
    @ObservationIgnored private var settingsObserver: NSObjectProtocol?
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var favoriteTask: Task<Void, Never>?

    init(source: NowPlayingSource, favorites: FavoriteService) {
        self.source = source
        self.favorites = favorites
        source.onChange = { [weak self] in self?.update($0) }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
    }

    func start() { source.start() }

    func stop() { source.stop() }

    // MARK: - Actions

    func togglePlayPause() {
        source.send(.togglePlayPause)
    }

    func next() { source.send(.nextTrack) }
    func previous() { source.send(.previousTrack) }

    func seek(toProgress progress: Double) {
        guard let duration = nowPlaying?.duration else { return }
        source.seek(to: duration * min(max(progress, 0), 1))
    }

    func toggleFavorite() {
        guard let current = isFavorite else { return }
        isFavorite = !current
        favoriteTask?.cancel()
        favoriteTask = Task { [favorites] in await favorites.setFavorite(!current) }
    }

    func openSource() {
        guard let id = nowPlaying?.sourceBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Private

    private func update(_ state: NowPlaying?) {
        let trackChanged = state?.title != nowPlaying?.title || state?.artist != nowPlaying?.artist
        if trackChanged, nowPlaying != nil, state?.isPlaying == true { peek() }
        if trackChanged || state?.sourceBundleIdentifier != nowPlaying?.sourceBundleIdentifier {
            refreshFavorite(for: state)
        }
        let artworkChanged = state?.artworkData != nowPlaying?.artworkData
        // Players briefly report no artwork while switching tracks; keep the old cover until the new one arrives.
        let keepArtwork = state?.artworkData == nil && state?.title == nowPlaying?.title
        if state?.sourceBundleIdentifier != nowPlaying?.sourceBundleIdentifier {
            sourceIcon = state.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.sourceBundleIdentifier) }
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
        nowPlaying = state
        if artworkChanged, !keepArtwork {
            artworkID += 1
            if let data = state?.artworkData {
                artwork = NSImage(data: data)
                tint = ArtworkTint.color(for: data) ?? .islandPrimary
            } else {
                artwork = nil
                tint = .islandPrimary
            }
        }
        updateVisibility()
    }

    private func updateVisibility() {
        let hideWhenPaused = UserDefaults.standard.bool(forKey: SettingsKey.hideWhenPaused)
        let visible = nowPlaying.map { $0.isPlaying || !hideWhenPaused } ?? false
        if visible != isVisible { isVisible = visible }
    }

    private func peek() {
        guard UserDefaults.standard.bool(forKey: SettingsKey.peekOnTrackChange) else { return }
        peekTask?.cancel()
        isPeeking = true
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.isPeeking = false
        }
    }

    private func refreshFavorite(for state: NowPlaying?) {
        favoriteTask?.cancel()
        isFavorite = nil
        guard let state, favorites.supports(bundleIdentifier: state.sourceBundleIdentifier) else { return }
        favoriteTask = Task { [weak self, favorites] in
            let value = await favorites.isFavorite()
            guard !Task.isCancelled else { return }
            self?.isFavorite = value
        }
    }
}
