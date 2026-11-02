import Foundation
import OSLog

/// Media commands, mapped to the adapter's MRCommand IDs.
enum MediaCommand: Int, Sendable {
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

@MainActor
protocol NowPlayingSource: AnyObject {
    /// Called on every change, nil when nothing is playing.
    var onChange: ((NowPlaying?) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MediaCommand)
    func seek(to seconds: TimeInterval)
}

/// Reads system-wide Now Playing through mediaremote-adapter.
///
/// Since macOS 15.4 MediaRemote only answers entitled Apple processes, so the bundled adapter
/// framework is loaded into /usr/bin/perl, which is allowed to use it. The script streams JSON
/// lines on stdout and takes commands as separate invocations.
@MainActor
final class NowPlayingService: NowPlayingSource {
    var onChange: ((NowPlaying?) -> Void)?

    private let log = Logger(subsystem: "com.iamginsley.smollnotch", category: "NowPlaying")
    private var process: Process?
    private var readTask: Task<Void, Never>?
    private var restartDelay: Duration = .seconds(1)
    private var isRunning = false

    private static let perl = URL(filePath: "/usr/bin/perl")

    private var adapterArguments: [String]? {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = Bundle.main.privateFrameworksURL?.appending(path: "MediaRemoteAdapter.framework")
        else { return nil }
        return [script.path, framework.path]
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        launchStream()
    }

    func stop() {
        isRunning = false
        readTask?.cancel()
        process?.terminate()
        process = nil
    }

    func send(_ command: MediaCommand) {
        run(["send", String(command.rawValue)])
    }

    func seek(to seconds: TimeInterval) {
        run(["seek", String(Int(max(seconds, 0) * 1_000_000))])
    }

    // MARK: - Private

    private func launchStream() {
        guard isRunning, let adapter = adapterArguments else {
            log.error("Adapter script or framework missing from the bundle")
            return
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = adapter + ["stream", "--micros", "--debounce=50"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in self?.streamEnded(status: status) }
        }
        do {
            try process.run()
        } catch {
            log.error("Could not launch adapter: \(error.localizedDescription)")
            return
        }
        self.process = process

        let handle = pipe.fileHandleForReading
        readTask = Task.detached { [weak self] in
            var stream = NowPlayingStream()
            do {
                // Lines can be several hundred KB when they carry artwork, so split on raw bytes.
                var buffer = Data()
                for try await byte in handle.bytes {
                    if byte == UInt8(ascii: "\n") {
                        let state = stream.apply(line: buffer)
                        buffer.removeAll(keepingCapacity: true)
                        await self?.publish(state)
                    } else {
                        buffer.append(byte)
                    }
                }
            } catch {}
        }
        restartDelay = .seconds(1)
    }

    private func publish(_ state: NowPlaying?) {
        onChange?(state)
    }

    private func streamEnded(status: Int32) {
        process = nil
        guard isRunning else { return }
        log.error("Adapter stream ended with status \(status), restarting in \(self.restartDelay)")
        onChange?(nil)
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, .seconds(30))
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.launchStream()
        }
    }

    private func run(_ command: [String]) {
        guard let adapter = adapterArguments else { return }
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = adapter + command
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
