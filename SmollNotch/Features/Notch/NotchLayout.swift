import CoreGraphics

/// Frames of every island element, in island coordinates (origin top left), for one mode.
///
/// Artwork and equalizer exist in both compact and expanded mode, so they are single views that
/// move between these frames instead of fading out and back in.
struct NotchLayout: Equatable {
    var size: CGSize
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var artwork: CGRect
    var artworkCornerRadius: CGFloat
    var equalizer: CGRect
    /// The band beside the notch in expanded mode, holding the source app icon.
    var header: CGRect
    var text: CGRect
    var progress: CGRect
    var volume: CGRect

    static let expandedArtwork: CGFloat = 92
    private static let inset: CGFloat = 22

    init(mode: NotchIsland.Mode, notchSize: CGSize, floating: Bool = false, showsProgress: Bool, showsVolume: Bool = false) {
        let notch = notchSize
        switch mode {
        case .hidden, .compact:
            let wing = notch.height + 12
            let width = mode == .hidden ? notch.width : notch.width + 2 * wing
            let artworkSide = notch.height - 10
            let equalizerSize = CGSize(width: 18, height: artworkSide * 0.6)
            size = CGSize(width: width, height: notch.height)
            topRadius = 6
            // A floating pill is a capsule; attached to the notch the bottom matches its corners.
            bottomRadius = floating ? notch.height / 2 : 14
            // Hidden: everything collapses into the middle, behind the hardware notch.
            let artworkX = mode == .hidden ? (width - artworkSide) / 2 : (wing - artworkSide) / 2
            let equalizerX = mode == .hidden ? (width - equalizerSize.width) / 2 : width - wing + (wing - equalizerSize.width) / 2
            artwork = CGRect(x: artworkX, y: 5, width: artworkSide, height: artworkSide)
            artworkCornerRadius = floating ? artworkSide / 2 : 6
            equalizer = CGRect(origin: CGPoint(x: equalizerX, y: (notch.height - equalizerSize.height) / 2), size: equalizerSize)
            header = .zero
            text = CGRect(x: artwork.maxX + 12, y: 0, width: 0, height: notch.height)
            progress = .zero
            volume = .zero

        case .expanded:
            let width = max(notch.width + 230, 480)
            topRadius = 14
            bottomRadius = floating ? 26 : 32
            let edge = topRadius + Self.inset
            let top = notch.height + 8
            let side = Self.expandedArtwork
            artwork = CGRect(x: edge, y: top, width: side, height: side)
            artworkCornerRadius = 16
            let equalizerSize = CGSize(width: 22, height: 14)
            equalizer = CGRect(origin: CGPoint(x: width - edge - equalizerSize.width, y: (notch.height - equalizerSize.height) / 2),
                               size: equalizerSize)
            header = CGRect(x: edge, y: 0, width: (width - notch.width) / 2 - edge - 8, height: notch.height)
            text = CGRect(x: artwork.maxX + 16, y: top, width: width - edge - artwork.maxX - 16, height: side)
            var bottom = artwork.maxY
            progress = .zero
            volume = .zero
            if showsProgress {
                progress = CGRect(x: edge, y: bottom + 10, width: width - 2 * edge, height: 22)
                bottom = progress.maxY
            }
            if showsVolume {
                volume = CGRect(x: edge, y: bottom + (showsProgress ? 4 : 10), width: width - 2 * edge, height: 26)
                bottom = volume.maxY
            }
            // Grow only as tall as the content (HIG: Live Activities › dynamically change the height).
            size = CGSize(width: width, height: bottom + 14)
        }
    }
}
