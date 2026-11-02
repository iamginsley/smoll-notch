import CoreGraphics
import Observation

/// One island on one screen: its notch geometry and hover state on top of the shared playback model.
@MainActor
@Observable
final class NotchIsland {
    enum Mode: Equatable {
        /// Nothing to show: the island hides behind the hardware notch.
        case hidden
        /// Playing, mouse elsewhere: artwork left of the notch, equalizer right of it.
        case compact
        /// Hovered or peeking after a track change: the full player.
        case expanded
    }

    let model: NotchViewModel
    /// Size of the hardware notch, or of the pill on screens without one.
    var notchSize: CGSize
    /// False on screens without a notch: the island floats as a pill below the top edge instead.
    var hasNotch: Bool
    var isHovering = false
    private let forceExpanded: Bool

    /// Gap between the screen's top edge and a floating pill.
    nonisolated static let pillTopInset: CGFloat = 4
    /// Stand-in "notch" for screens without one: a short gap between the two wings of the pill.
    nonisolated static let pillSize = CGSize(width: 44, height: 28)

    init(model: NotchViewModel, notchSize: CGSize, hasNotch: Bool, forceExpanded: Bool = false) {
        self.model = model
        self.notchSize = notchSize
        self.hasNotch = hasNotch
        self.forceExpanded = forceExpanded
    }

    var mode: Mode {
        guard model.isVisible else { return .hidden }
        return isHovering || forceExpanded || model.isPeeking ? .expanded : .compact
    }

    var topInset: CGFloat { hasNotch ? 0 : Self.pillTopInset }

    /// Frames for the current mode. The window controller uses `layout.size` for hit testing too.
    var layout: NotchLayout {
        NotchLayout(
            mode: mode, notchSize: notchSize, floating: !hasNotch,
            showsProgress: model.nowPlaying?.duration != nil
        )
    }
}
