import CoreGraphics
import Testing
@testable import SmollNotch

struct IslandGesturesTests {
    @Test func horizontalSwipeSkipsOncePerGesture() {
        var gestures = IslandGestures()
        var actions: [IslandGestures.Action] = []
        let steps: [(CGFloat, IslandGestures.Phase)] = [(-5, .began), (-30, .changed), (-30, .changed), (-30, .changed), (0, .ended)]
        for (dx, phase) in steps {
            if let action = gestures.handle(delta: CGVector(dx: dx, dy: 0), phase: phase, precise: true) { actions.append(action) }
        }
        #expect(actions == [.next])
    }

    @Test func swipeRightGoesBack() {
        var gestures = IslandGestures()
        _ = gestures.handle(delta: CGVector(dx: 10, dy: 0), phase: .began, precise: true)
        #expect(gestures.handle(delta: CGVector(dx: 60, dy: 2), phase: .changed, precise: true) == .previous)
    }

    @Test func verticalSwipeDoesNothing() {
        var gestures = IslandGestures()
        _ = gestures.handle(delta: CGVector(dx: 0, dy: 20), phase: .began, precise: true)
        #expect(gestures.handle(delta: CGVector(dx: 0, dy: 80), phase: .changed, precise: true) == nil)
        // Locked to vertical: a later sideways drift does not skip either.
        #expect(gestures.handle(delta: CGVector(dx: -80, dy: 0), phase: .changed, precise: true) == nil)
    }

    @Test func wheelMiceAreIgnored() {
        var gestures = IslandGestures()
        #expect(gestures.handle(delta: CGVector(dx: -80, dy: 0), phase: .none, precise: false) == nil)
        #expect(gestures.handle(delta: CGVector(dx: 0, dy: 3), phase: .none, precise: false) == nil)
    }
}

struct ScreenChoiceTests {
    @Test func builtInPrefersTheNotchScreen() {
        #expect(ScreenChoice.builtIn.screenIndices(hasNotch: [false, true]) == [1])
        #expect(ScreenChoice.builtIn.screenIndices(hasNotch: [false, false]) == [0])
    }

    @Test func mainAndAll() {
        #expect(ScreenChoice.main.screenIndices(hasNotch: [false, true]) == [0])
        #expect(ScreenChoice.all.screenIndices(hasNotch: [true, false, false]) == [0, 1, 2])
        #expect(ScreenChoice.all.screenIndices(hasNotch: []) == [])
    }
}

@MainActor
struct FavoriteStateTests {
    @Test func loadsFavoriteStateForTheTrack() async throws {
        let model = NotchViewModel(source: DemoNowPlayingSource(), favorites: DemoFavoriteService())
        model.start()
        for _ in 0..<50 where model.isFavorite == nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.isFavorite == false)
        model.toggleFavorite()
        #expect(model.isFavorite == true)
    }
}
