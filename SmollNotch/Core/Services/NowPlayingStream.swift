import Foundation

/// Folds the adapter's JSON lines (`stream --micros`) into the current `NowPlaying`.
///
/// Every line is `{"type":"data","diff":Bool,"payload":{...}}`. A full payload replaces the state,
/// a diff only carries changed keys, and a key set to null has vanished.
struct NowPlayingStream {
    private var fields: [String: Any] = [:]

    /// Applies one line and returns the resulting state, nil when nothing is playing.
    mutating func apply(line: Data) -> NowPlaying? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "data",
              let payload = object["payload"] as? [String: Any]
        else { return Self.nowPlaying(from: fields) }

        if object["diff"] as? Bool == true {
            for (key, value) in payload {
                if value is NSNull { fields[key] = nil } else { fields[key] = value }
            }
        } else {
            fields = payload.filter { !($0.value is NSNull) }
        }
        return Self.nowPlaying(from: fields)
    }

    static func nowPlaying(from fields: [String: Any]) -> NowPlaying? {
        guard let title = (fields["title"] as? String)?.trimmingCharacters(in: .whitespaces), !title.isEmpty,
              let bundleIdentifier = fields["bundleIdentifier"] as? String
        else { return nil }

        func seconds(_ key: String) -> TimeInterval? {
            (fields[key] as? NSNumber).map { $0.doubleValue / 1_000_000 }
        }
        func text(_ key: String) -> String? {
            guard let value = fields[key] as? String, !value.isEmpty else { return nil }
            return value
        }

        return NowPlaying(
            title: title,
            artist: text("artist"),
            album: text("album"),
            isPlaying: fields["playing"] as? Bool ?? false,
            duration: seconds("durationMicros").flatMap { $0 > 0 ? $0 : nil },
            elapsed: seconds("elapsedTimeMicros"),
            timestamp: seconds("timestampEpochMicros").map(Date.init(timeIntervalSince1970:)),
            playbackRate: (fields["playbackRate"] as? NSNumber)?.doubleValue ?? 1,
            bundleIdentifier: bundleIdentifier,
            parentBundleIdentifier: text("parentApplicationBundleIdentifier"),
            artworkData: text("artworkData").flatMap { Data(base64Encoded: $0) }
        )
    }
}
