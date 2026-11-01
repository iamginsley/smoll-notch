import AppKit
import SwiftUI
import Testing
@testable import SmollNotch

@MainActor
struct SnapshotRender {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] != nil))
    func render() throws {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!
        // Second demo track has a 16:9 thumbnail, like YouTube.
        for (name, expanded, wide) in [("expanded", true, false), ("expanded-wide", true, true), ("compact", false, false)] {
            let model = NotchViewModel(source: DemoNowPlayingSource(), forceExpanded: expanded)
            model.notchSize = CGSize(width: 185, height: 32)
            model.start()
            if wide { model.next() }
            // Render through a real hosting view so the result matches what the panel draws.
            let view = NSHostingView(rootView: NotchView(model: model).frame(width: 680, height: 240).background(Color.gray))
            view.frame = CGRect(x: 0, y: 0, width: 680, height: 240)
            let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: .now + 1)
            let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            let png = rep.representation(using: .png, properties: [:])
            try png?.write(to: URL(filePath: dir).appending(path: "\(name).png"))
        }
    }
}
