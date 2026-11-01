import AppKit
import SwiftUI

/// A borderless panel that sits over the notch and can take clicks without activating the app.
private final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar + 1
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Places one island on one screen and decides when it is hovered.
///
/// The panel is larger than the island so the island can grow without resizing the window.
/// Clicks pass through everywhere except the island itself.
@MainActor
final class NotchWindowController {
    let island: NotchIsland
    private(set) var screen: NSScreen
    private let panel = NotchPanel()
    private var monitors: [Any] = []
    private var collapseTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?
    private var gestures = IslandGestures()

    private static let panelSize = CGSize(width: 680, height: 280)

    init(model: NotchViewModel, screen: NSScreen, forceExpanded: Bool = false) {
        self.screen = screen
        let geometry = Self.notchGeometry(of: screen)
        island = NotchIsland(model: model, notchSize: geometry.size, hasNotch: geometry.hasNotch, forceExpanded: forceExpanded)
        let hosting = NSHostingView(rootView: NotchView(island: island))
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    func show() {
        position()
        panel.orderFrontRegardless()

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.scrolled(event) ?? false } ? nil : event
        } as Any)
        observeMode()
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        collapseTask?.cancel()
        expandTask?.cancel()
        panel.orderOut(nil)
    }

    /// Moves the island to an updated screen object (resolution or arrangement changed).
    func update(screen: NSScreen) {
        self.screen = screen
        position()
    }

    // MARK: - Placement

    static func notchGeometry(of screen: NSScreen) -> (size: CGSize, hasNotch: Bool) {
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return (CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top), true)
        }
        return (NotchIsland.pillSize, false)
    }

    private func position() {
        let geometry = Self.notchGeometry(of: screen)
        island.notchSize = geometry.size
        island.hasNotch = geometry.hasNotch
        let frame = screen.frame
        let size = Self.panelSize
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    // MARK: - Hover

    /// The island's rectangle in screen coordinates.
    private var islandFrame: CGRect {
        let panelFrame = panel.frame
        let size = island.layout.size
        return CGRect(x: panelFrame.midX - size.width / 2, y: panelFrame.maxY - island.topInset - size.height,
                      width: size.width, height: size.height)
    }

    private func mouseMoved() {
        let location = NSEvent.mouseLocation
        let inside = island.mode != .hidden && islandFrame.insetBy(dx: -4, dy: -4).contains(location)
        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            if !island.isHovering, expandTask == nil {
                // Hover intent: passing through on the way to the menu bar should not open the island.
                expandTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(90))
                    guard !Task.isCancelled, let self else { return }
                    self.island.isHovering = true
                    self.expandTask = nil
                    self.updateMouseHandling()
                }
            }
        } else if !island.isHovering {
            expandTask?.cancel()
            expandTask = nil
        } else if collapseTask == nil {
            // A short grace period so a quick wobble past the edge does not snap it shut.
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                self.island.isHovering = false
                self.collapseTask = nil
            }
        }
        updateMouseHandling()
    }

    private func updateMouseHandling() {
        panel.ignoresMouseEvents = !(island.isHovering && island.mode == .expanded)
    }

    /// Swipes and scrolls over the open island. Returns true when the event was used.
    private func scrolled(_ event: NSEvent) -> Bool {
        guard event.window === panel, island.isHovering, island.mode == .expanded,
              event.momentumPhase.isEmpty
        else { return false }
        // Normalize to finger movement: right and up are positive, whatever the scroll direction setting.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let delta = CGVector(dx: event.scrollingDeltaX * sign, dy: -event.scrollingDeltaY * sign)
        let phase: IslandGestures.Phase = switch event.phase {
        case .began, .mayBegin: .began
        case .ended, .cancelled: .ended
        case []: .none
        default: .changed
        }
        switch gestures.handle(delta: delta, phase: phase, precise: event.hasPreciseScrollingDeltas) {
        case .next: island.model.next()
        case .previous: island.model.previous()
        case .volume(let change): island.model.changeVolume(by: change)
        case nil: break
        }
        return true
    }

    private func observeMode() {
        withObservationTracking {
            _ = island.mode
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateMouseHandling()
                self?.observeMode()
            }
        }
    }
}
