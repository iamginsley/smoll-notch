import AppKit
import SwiftUI
import Testing
@testable import SmollNotch

@MainActor
struct SnapshotRender {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] != nil))
    func render() throws {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!
        for expanded in [false, true] {
            let model = NotchViewModel(source: DemoNowPlayingSource(), forceExpanded: expanded)
            model.notchSize = CGSize(width: 185, height: 32)
            model.start()
            let renderer = ImageRenderer(content: NotchView(model: model).frame(width: 680, height: 240).background(Color.gray))
            renderer.scale = 2
            let tiff = try #require(renderer.nsImage?.tiffRepresentation)
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            try png?.write(to: URL(filePath: dir).appending(path: expanded ? "expanded.png" : "compact.png"))
        }
    }
}
