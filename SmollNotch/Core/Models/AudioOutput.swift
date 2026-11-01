import CoreAudio

struct AudioOutputDevice: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case builtInSpeakers, headphones, airPods, airPodsPro, airPodsMax, bluetooth, airPlay, display, external
    }

    let id: AudioObjectID
    let name: String
    let kind: Kind

    /// SF Symbol for the device, so people recognize their AirPods at a glance.
    var symbol: String {
        switch kind {
        case .builtInSpeakers: "laptopcomputer"
        case .headphones: "headphones"
        case .airPods: "airpods"
        case .airPodsPro: "airpodspro"
        case .airPodsMax: "airpodsmax"
        case .bluetooth: "hifispeaker"
        case .airPlay: "airplayaudio"
        case .display: "display"
        case .external: "hifispeaker"
        }
    }

    static func kind(name: String, transport: UInt32) -> Kind {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return .airPodsMax }
        if lower.contains("airpods pro") { return .airPodsPro }
        if lower.contains("airpods") { return .airPods }
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return lower.contains("kopfhörer") || lower.contains("headphone") ? .headphones : .builtInSpeakers
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return lower.contains("beats") || lower.contains("headphone") || lower.contains("kopfhörer") ? .headphones : .bluetooth
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .display
        default:
            return .external
        }
    }
}

struct AudioOutput: Equatable, Sendable {
    var device: AudioOutputDevice
    /// 0...1, nil when the device has no software volume (some HDMI and USB devices).
    var volume: Float?
    var isMuted: Bool

    /// Speaker symbol that follows the level, like the system volume control.
    var volumeSymbol: String {
        guard let volume, !isMuted, volume > 0 else { return "speaker.slash.fill" }
        return volume < 0.34 ? "speaker.wave.1.fill" : volume < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}
