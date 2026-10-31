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

/// Places the island over the notch and decides when it is hovered.
///
/// The panel is larger than the island so the island can grow without resizing the window.
/// Clicks pass through everywhere except the island itself.
@MainActor
final class NotchWindowController {
    private let model: NotchViewModel
    private let panel = NotchPanel()
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var collapseTask: Task<Void, Never>?

    private static let panelSize = CGSize(width: 680, height: 260)

    init(model: NotchViewModel) {
        self.model = model
        let hosting = NSHostingView(rootView: NotchView(model: model))
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
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.position() }
        }
        observeMode()
    }

    // MARK: - Placement

    /// The built-in display with the notch, otherwise the main screen.
    private var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func position() {
        guard let screen else { return }
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            model.notchSize = CGSize(width: frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
            model.hasNotch = true
        } else {
            model.notchSize = CGSize(width: 185, height: NSStatusBar.system.thickness)
            model.hasNotch = false
        }
        let size = Self.panelSize
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    // MARK: - Hover

    /// The island's rectangle in screen coordinates.
    private var islandFrame: CGRect {
        let panelFrame = panel.frame
        let island = model.islandSize
        return CGRect(x: panelFrame.midX - island.width / 2, y: panelFrame.maxY - island.height,
                      width: island.width, height: island.height)
    }

    private func mouseMoved() {
        let location = NSEvent.mouseLocation
        let inside = model.mode != .hidden && islandFrame.insetBy(dx: -4, dy: -4).contains(location)
        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            if !model.isHovering { model.isHovering = true }
        } else if model.isHovering, collapseTask == nil {
            // A short grace period so a quick wobble past the edge does not snap it shut.
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                self.model.isHovering = false
                self.collapseTask = nil
            }
        }
        updateMouseHandling()
    }

    private func updateMouseHandling() {
        panel.ignoresMouseEvents = !(model.isHovering && model.mode == .expanded)
    }

    private func observeMode() {
        withObservationTracking {
            _ = model.mode
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateMouseHandling()
                self?.observeMode()
            }
        }
    }
}
