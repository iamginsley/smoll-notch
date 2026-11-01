#if DEBUG
import AppKit

/// Sample playback for screenshots and UI work, enabled with the `-SmollNotchDemo` launch flag.
@MainActor
final class DemoNowPlayingSource: NowPlayingSource {
    var onChange: ((NowPlaying?) -> Void)?

    private var tracks: [NowPlaying] = [
        .demo(title: "Kleiner Dackel, großer Hund", artist: "Die Smolls", album: "Sofa Sessions", duration: 187, hue: 0.07),
        // A video with a 16:9 thumbnail, like YouTube in a browser.
        .demo(title: "Notch Notch, wer ist da? Die ganze Geschichte in einem viel zu langen Videotitel", artist: "Ginsley", album: nil,
              duration: 624, hue: 0.58, artworkSize: NSSize(width: 480, height: 270)),
        .demo(title: "Lauscher auf", artist: "Waldi & Band", album: "Gassi", duration: 161, hue: 0.83),
    ]
    private var index = 0

    func start() {
        tracks[index].timestamp = .now
        onChange?(tracks[index])
    }

    func stop() {}

    func send(_ command: MediaCommand) {
        let current = tracks[index]
        switch command {
        case .togglePlayPause:
            tracks[index].elapsed = current.position(at: .now)
            tracks[index].isPlaying.toggle()
        case .nextTrack:
            index = (index + 1) % tracks.count
        case .previousTrack:
            index = (index + tracks.count - 1) % tracks.count
        }
        if command != .togglePlayPause {
            tracks[index].elapsed = 0
            tracks[index].isPlaying = true
        }
        tracks[index].timestamp = .now
        onChange?(tracks[index])
    }

    func seek(to seconds: TimeInterval) {
        tracks[index].elapsed = seconds
        tracks[index].timestamp = .now
        onChange?(tracks[index])
    }
}

private extension NowPlaying {
    static func demo(title: String, artist: String, album: String?, duration: TimeInterval, hue: Double,
                     artworkSize: NSSize = NSSize(width: 300, height: 300)) -> NowPlaying {
        NowPlaying(
            title: title, artist: artist, album: album, isPlaying: true,
            duration: duration, elapsed: duration * 0.3, timestamp: .now, playbackRate: 1,
            bundleIdentifier: "com.apple.Music", parentBundleIdentifier: nil,
            artworkData: demoArtwork(hue: hue, size: artworkSize)
        )
    }

    /// A soft two-tone gradient so the tint and layout can be judged without real covers.
    static func demoArtwork(hue: Double, size: NSSize) -> Data? {
        let image = NSImage(size: size, flipped: false) { rect in
            let top = NSColor(hue: hue, saturation: 0.75, brightness: 0.95, alpha: 1)
            let bottom = NSColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 0.55, alpha: 1)
            NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
            return true
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
