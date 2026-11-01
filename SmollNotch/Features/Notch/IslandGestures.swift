import CoreGraphics

/// Turns two-finger swipes on the island into track skips: fingers left for the next track,
/// right for the previous one, once per gesture. Vertical swipes and mouse wheels are ignored.
struct IslandGestures {
    enum Action: Equatable {
        case next, previous
    }

    enum Phase { case began, changed, ended, none }

    private enum Axis { case horizontal, vertical }

    private var total = CGVector.zero
    private var axis: Axis?
    private var didSkip = false

    static let skipDistance: CGFloat = 60
    static let lockDistance: CGFloat = 8

    /// - Parameters:
    ///   - delta: Finger movement in points, normalized so positive x is right and positive y is up.
    ///   - precise: True for trackpads and Magic Mouse, false for classic wheel mice.
    mutating func handle(delta: CGVector, phase: Phase, precise: Bool) -> Action? {
        guard precise else { return nil }
        if phase == .began { reset() }
        defer { if phase == .ended { reset() } }

        total.dx += delta.dx
        total.dy += delta.dy
        if axis == nil, max(abs(total.dx), abs(total.dy)) >= Self.lockDistance {
            axis = abs(total.dx) > abs(total.dy) ? .horizontal : .vertical
        }

        switch axis {
        case .horizontal:
            guard !didSkip, abs(total.dx) >= Self.skipDistance else { return nil }
            didSkip = true
            return total.dx < 0 ? .next : .previous
        case .vertical, nil:
            return nil
        }
    }

    private mutating func reset() {
        total = .zero
        axis = nil
        didSkip = false
    }
}
