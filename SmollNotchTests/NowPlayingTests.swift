import Foundation
import Testing
@testable import SmollNotch

struct NowPlayingStreamTests {
    private func line(_ json: String) -> Data { Data(json.utf8) }

    @Test func fullPayloadBuildsState() throws {
        var stream = NowPlayingStream()
        let applied = stream.apply(line: line("""
        {"type":"data","diff":false,"payload":{"title":"Be Her","artist":"Ella Langley","album":"Dandelion",
        "playing":true,"bundleIdentifier":"com.apple.Music","durationMicros":217283000,
        "elapsedTimeMicros":30501442,"timestampEpochMicros":1793409675000000,"playbackRate":1}}
        """))
        let state = try #require(applied)
        #expect(state.title == "Be Her")
        #expect(state.artist == "Ella Langley")
        #expect(state.album == "Dandelion")
        #expect(state.isPlaying)
        #expect(state.duration == 217.283)
        #expect(abs((state.elapsed ?? 0) - 30.501442) < 0.000_001)
        #expect(state.timestamp == Date(timeIntervalSince1970: 1_793_409_675))
    }

    @Test func diffUpdatesAndRemovesKeys() throws {
        var stream = NowPlayingStream()
        _ = stream.apply(line: line("""
        {"type":"data","diff":false,"payload":{"title":"A","album":"X","playing":true,"bundleIdentifier":"com.spotify.client"}}
        """))
        let applied = stream.apply(line: line("""
        {"type":"data","diff":true,"payload":{"playing":false,"album":null}}
        """))
        let state = try #require(applied)
        #expect(state.title == "A")
        #expect(!state.isPlaying)
        #expect(state.album == nil)
    }

    @Test func emptyPayloadMeansNothingPlays() {
        var stream = NowPlayingStream()
        _ = stream.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"bundleIdentifier":"x"}}"#))
        let state = stream.apply(line: line(#"{"type":"data","diff":false,"payload":{}}"#))
        #expect(state == nil)
    }

    @Test func garbageKeepsLastState() {
        var stream = NowPlayingStream()
        _ = stream.apply(line: line(#"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"bundleIdentifier":"x"}}"#))
        let state = stream.apply(line: line("not json"))
        #expect(state?.title == "A")
    }

    @Test func browserReportsParentApp() throws {
        var stream = NowPlayingStream()
        let applied = stream.apply(line: line("""
        {"type":"data","diff":false,"payload":{"title":"Video","playing":true,
        "bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari"}}
        """))
        let state = try #require(applied)
        #expect(state.sourceBundleIdentifier == "com.apple.Safari")
    }
}

struct NowPlayingPositionTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func track(playing: Bool, rate: Double = 1) -> NowPlaying {
        NowPlaying(title: "A", artist: nil, album: nil, isPlaying: playing, duration: 100, elapsed: 10,
                   timestamp: start, playbackRate: rate, bundleIdentifier: "x", parentBundleIdentifier: nil, artworkData: nil)
    }

    @Test func advancesWhilePlaying() {
        #expect(track(playing: true).position(at: start.addingTimeInterval(5)) == 15)
        #expect(track(playing: true, rate: 2).position(at: start.addingTimeInterval(5)) == 20)
    }

    @Test func standsStillWhenPaused() {
        #expect(track(playing: false).position(at: start.addingTimeInterval(5)) == 10)
    }

    @Test func clampsToDuration() {
        #expect(track(playing: true).position(at: start.addingTimeInterval(500)) == 100)
        #expect(track(playing: true).progress(at: start.addingTimeInterval(40)) == 0.5)
    }

    @Test func formatsTimes() {
        #expect(TimeInterval(7).playbackTime == "0:07")
        #expect(TimeInterval(187.9).playbackTime == "3:07")
        #expect(TimeInterval(3723).playbackTime == "1:02:03")
    }
}

struct ArtworkTintTests {
    @Test(arguments: [
        (0.0, 0.0, 0.0), (0.05, 0.02, 0.1), (0.3, 0.1, 0.1), (0.1, 0.1, 0.6), (1.0, 1.0, 1.0), (0.5, 0.5, 0.5),
    ])
    func tintReadsOnBlack(red: Double, green: Double, blue: Double) {
        let tint = ArtworkTint.readable(red: red, green: green, blue: blue)
        #expect(ArtworkTint.contrastOnBlack(tint) >= 4.5)
    }
}
