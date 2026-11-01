import CoreGraphics

/// Turns scroll events on the island into media actions.
///
/// Trackpad: a horizontal two-finger swipe skips tracks (fingers left: next, right: previous), once per
/// gesture; a vertical swipe changes the volume continuously (fingers up: louder).
/// Mouse wheel: each notch changes the volume a step.
struct IslandGestures {
    enum Action: Equatable {
        case next, previous
        case volume(Double)
    }

    enum Phase { case began, changed, ended, none }

    private enum Axis { case horizontal, vertical }

    private var total = CGVector.zero
    private var axis: Axis?
    private var didSkip = false

    static let skipDistance: CGFloat = 60
    static let lockDistance: CGFloat = 8
    static let volumePerPoint = 0.004
    static let wheelStep = 0.05

    /// - Parameters:
    ///   - delta: Finger movement in points, normalized so positive x is right and positive y is up.
    ///   - precise: True for trackpads and Magic Mouse, false for classic wheel mice.
    mutating func handle(delta: CGVector, phase: Phase, precise: Bool) -> Action? {
        guard precise else {
            // Wheel mice: vertical only, one step per tick.
            guard delta.dy != 0 else { return nil }
            return .volume(delta.dy > 0 ? Self.wheelStep : -Self.wheelStep)
        }
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
        case .vertical:
            return delta.dy == 0 ? nil : .volume(Double(delta.dy) * Self.volumePerPoint)
        case nil:
            return nil
        }
    }

    private mutating func reset() {
        total = .zero
        axis = nil
        didSkip = false
    }
}
