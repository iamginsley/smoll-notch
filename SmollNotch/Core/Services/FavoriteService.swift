import Foundation

/// Marks the current track as a favorite in the app that plays it.
protocol FavoriteService: Sendable {
    func supports(bundleIdentifier: String) -> Bool
    /// The current track's favorite state, nil when it cannot be read (e.g. Automation not allowed).
    func isFavorite() async -> Bool?
    func setFavorite(_ favorite: Bool) async
}

/// Apple Music through AppleScript. MediaRemote has no "like" command that Music honors, and
/// Spotify's scripting dictionary cannot save tracks, so Music is the only supported player.
///
/// The first call triggers the system's Automation prompt (NSAppleEventsUsageDescription).
struct MusicFavoriteService: FavoriteService {
    func supports(bundleIdentifier: String) -> Bool {
        bundleIdentifier == "com.apple.Music"
    }

    func isFavorite() async -> Bool? {
        let output = await Self.run(#"tell application "Music" to get favorited of current track"#)
        switch output {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    func setFavorite(_ favorite: Bool) async {
        _ = await Self.run(#"tell application "Music" to set favorited of current track to \#(favorite)"#)
    }

    /// Runs osascript off the main thread and returns its trimmed output, nil on failure.
    private static func run(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: process.terminationStatus == 0 ? output : nil)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

#if DEBUG
/// In-memory favorites for the demo mode, so screenshots never touch the real Music library.
final class DemoFavoriteService: FavoriteService, @unchecked Sendable {
    private let lock = NSLock()
    private var favorite = false

    func supports(bundleIdentifier: String) -> Bool { true }
    func isFavorite() async -> Bool? { lock.withLock { favorite } }
    func setFavorite(_ favorite: Bool) async { lock.withLock { self.favorite = favorite } }
}
#endif
