import Foundation

/// What the system reports as playing right now, from any app (Music, Spotify, a browser tab, ...).
struct NowPlaying: Equatable, Sendable {
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    /// Track length in seconds, nil for live streams and some web players.
    var duration: TimeInterval?
    /// Elapsed seconds at `timestamp`. Combine with `playbackRate` to get the live position.
    var elapsed: TimeInterval?
    var timestamp: Date?
    var playbackRate: Double
    /// The app that reports the media, e.g. com.apple.Music or com.google.Chrome.
    var bundleIdentifier: String
    /// Set for helper processes such as WebKit, points at the browser that owns them.
    var parentBundleIdentifier: String?
    var artworkData: Data?

    /// The app to bring forward when the artwork is clicked.
    var sourceBundleIdentifier: String { parentBundleIdentifier ?? bundleIdentifier }

    /// Live playback position, extrapolated from the last report.
    func position(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        var position = elapsed
        if isPlaying, let timestamp {
            position += date.timeIntervalSince(timestamp) * playbackRate
        }
        if let duration { position = min(position, duration) }
        return max(position, 0)
    }

    /// Progress from 0 to 1, nil when the length is unknown.
    func progress(at date: Date) -> Double? {
        guard let duration, duration > 0, let position = position(at: date) else { return nil }
        return position / duration
    }
}

extension TimeInterval {
    /// "3:07", or "1:02:03" for long podcasts.
    var playbackTime: String {
        let total = Int(self.rounded(.down))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
