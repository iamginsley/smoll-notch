import AppKit
import SwiftUI

@MainActor
@Observable
final class NotchViewModel {
    enum Mode: Equatable {
        /// Nothing to show: the island hides behind the hardware notch.
        case hidden
        /// Playing, mouse elsewhere: artwork left of the notch, equalizer right of it.
        case compact
        /// Hovered: the full player.
        case expanded
    }

    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    private(set) var tint: Color = .islandPrimary
    var isHovering = false {
        didSet { if isHovering != oldValue { updateMode() } }
    }
    private(set) var mode: Mode = .hidden
    /// Size of the hardware notch (or the stand-in on screens without one), set by the window controller.
    var notchSize = CGSize(width: 185, height: 32)
    var hasNotch = true

    private let source: NowPlayingSource
    private let forceExpanded: Bool
    @ObservationIgnored private var settingsObserver: NSObjectProtocol?

    init(source: NowPlayingSource, forceExpanded: Bool = false) {
        self.source = source
        self.forceExpanded = forceExpanded
        source.onChange = { [weak self] in self?.update($0) }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMode() }
        }
    }

    func start() { source.start() }
    func stop() { source.stop() }

    // MARK: - Layout

    /// Island size for the current mode. The window controller uses it for hit testing too.
    var islandSize: CGSize {
        switch mode {
        case .hidden: notchSize
        case .compact: CGSize(width: notchSize.width + 2 * compactWing, height: notchSize.height)
        case .expanded: CGSize(width: max(notchSize.width + 220, 470), height: notchSize.height + 150)
        }
    }

    /// Width of the artwork and equalizer "wings" beside the notch.
    var compactWing: CGFloat { notchSize.height + 12 }

    var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        mode == .expanded ? (14, 32) : (6, 14)
    }

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

    func openSource() {
        guard let id = nowPlaying?.sourceBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Private

    private func update(_ state: NowPlaying?) {
        let artworkChanged = state?.artworkData != nowPlaying?.artworkData
        // Players briefly report no artwork while switching tracks; keep the old cover until the new one arrives.
        let keepArtwork = state?.artworkData == nil && state?.title == nowPlaying?.title
        nowPlaying = state
        if artworkChanged, !keepArtwork {
            if let data = state?.artworkData {
                artwork = NSImage(data: data)
                tint = ArtworkTint.color(for: data) ?? .islandPrimary
            } else {
                artwork = nil
                tint = .islandPrimary
            }
        }
        updateMode()
    }

    private func updateMode() {
        let hideWhenPaused = UserDefaults.standard.bool(forKey: SettingsKey.hideWhenPaused)
        let visible = nowPlaying.map { $0.isPlaying || !hideWhenPaused } ?? false
        let newMode: Mode = !visible ? .hidden : (isHovering || forceExpanded) ? .expanded : .compact
        if newMode != mode { mode = newMode }
    }
}
