import AudioToolbox
import CoreAudio
import Foundation

/// The system's default output device, its volume, and the list of output devices, kept current
/// through CoreAudio property listeners.
@MainActor
final class AudioOutputService {
    var onChange: (() -> Void)?
    private(set) var current: AudioOutput?
    private(set) var devices: [AudioOutputDevice] = []

    private var listeningDevice: AudioObjectID?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        listen(on: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice)
        listen(on: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices)
        refresh()
    }

    func setVolume(_ volume: Float) {
        guard let id = current?.device.id else { return }
        var value = volume
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if current?.isMuted == true, volume > 0 {
            var unmute: UInt32 = 0
            var muteAddress = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectSetPropertyData(id, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &unmute)
        }
    }

    func select(_ device: AudioOutputDevice) {
        var id = device.id
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                   UInt32(MemoryLayout<AudioObjectID>.size), &id)
    }

    // MARK: - Private

    private func refresh() {
        devices = Self.outputDeviceIDs().compactMap(Self.device)
        guard let id = Self.defaultOutputID(), let device = Self.device(id) else {
            current = nil
            onChange?()
            return
        }
        if listeningDevice != id {
            listeningDevice = id
            listen(on: id, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
            listen(on: id, selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        }
        current = AudioOutput(device: device, volume: Self.volume(of: id), isMuted: Self.isMuted(id))
        onChange?()
    }

    /// Listeners stay registered for the app's lifetime; old devices simply stop firing.
    private func listen(on object: AudioObjectID, selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) {
        var address = Self.address(selector, scope: scope)
        AudioObjectAddPropertyListenerBlock(object, &address, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputID() -> AudioObjectID? {
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr && id != 0 ? id : nil
    }

    private static func outputDeviceIDs() -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasOutput)
    }

    private static func hasOutput(_ id: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func device(_ id: AudioObjectID) -> AudioOutputDevice? {
        var address = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr,
              let name = name?.takeRetainedValue() as String?
        else { return nil }
        var transport: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        var transportAddress = Self.address(kAudioDevicePropertyTransportType)
        AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transport)
        // Aggregate and virtual helper devices (e.g. from screen recorders) are not something to pick.
        if transport == kAudioDeviceTransportTypeAggregate || transport == kAudioDeviceTransportTypeVirtual { return nil }
        return AudioOutputDevice(id: id, name: name, kind: AudioOutputDevice.kind(name: name, transport: transport))
    }

    private static func volume(of id: AudioObjectID) -> Float? {
        var address = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &address, &settable)
        guard settable.boolValue else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &volume) == noErr ? volume : nil
    }

    private static func isMuted(_ id: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(id, &address) else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &muted) == noErr && muted != 0
    }
}
