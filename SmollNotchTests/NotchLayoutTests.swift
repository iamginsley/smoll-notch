import CoreGraphics
import Testing
@testable import SmollNotch

struct NotchLayoutTests {
    private let notch = CGSize(width: 185, height: 32)

    @Test func compactWingsFlankTheNotch() {
        let layout = NotchLayout(mode: .compact, notchSize: notch, showsProgress: true)
        let wing = (layout.size.width - notch.width) / 2
        #expect(layout.size.height == notch.height)
        #expect(layout.artwork.maxX <= wing)
        #expect(layout.equalizer.minX >= layout.size.width - wing)
    }

    @Test func expandedContentStaysInsideTheIsland() {
        let layout = NotchLayout(mode: .expanded, notchSize: notch, showsProgress: true)
        let bounds = CGRect(origin: .zero, size: layout.size)
        for frame in [layout.artwork, layout.text, layout.progress, layout.equalizer] {
            #expect(bounds.contains(frame))
        }
        // Content starts below the notch and clears the bottom corners.
        #expect(layout.artwork.minY >= notch.height)
        #expect(layout.artwork.minX >= layout.bottomRadius / 2)
    }

    @Test func expandedShrinksWithoutProgress() {
        let with = NotchLayout(mode: .expanded, notchSize: notch, showsProgress: true)
        let without = NotchLayout(mode: .expanded, notchSize: notch, showsProgress: false)
        #expect(without.size.height < with.size.height)
    }

    @Test func hiddenMatchesTheNotch() {
        let layout = NotchLayout(mode: .hidden, notchSize: notch, showsProgress: false)
        #expect(layout.size == notch)
    }
}
