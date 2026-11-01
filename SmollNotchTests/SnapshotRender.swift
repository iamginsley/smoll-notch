import AppKit
import SwiftUI
import Testing
@testable import SmollNotch

@MainActor
struct SnapshotRender {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] != nil))
    func render() async throws {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!
        // Second demo track has a 16:9 thumbnail, like YouTube.
        let cases = [
            ("expanded", true, false, true), ("expanded-wide", true, true, true), ("compact", false, false, true),
            ("pill", false, false, false), ("pill-expanded", true, false, false),
        ]
        for (name, expanded, wide, hasNotch) in cases {
            let model = NotchViewModel(source: DemoNowPlayingSource(), favorites: DemoFavoriteService())
            let notch = hasNotch ? CGSize(width: 185, height: 32) : NotchIsland.pillSize
            let island = NotchIsland(model: model, notchSize: notch, hasNotch: hasNotch, forceExpanded: expanded)
            model.start()
            if wide { model.next() }
            // Render through a real hosting view so the result matches what the panel draws.
            let view = NSHostingView(rootView: NotchView(island: island).frame(width: 680, height: 260).background(Color.gray))
            view.frame = CGRect(x: 0, y: 0, width: 680, height: 260)
            let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            // Yield (rather than spinning the run loop) so main-actor tasks such as the favorite lookup run.
            try await Task.sleep(for: .seconds(1))
            let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            let png = rep.representation(using: .png, properties: [:])
            try png?.write(to: URL(filePath: dir).appending(path: "\(name).png"))
        }
    }
}
