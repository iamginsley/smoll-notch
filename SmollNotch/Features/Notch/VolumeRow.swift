import SwiftUI

/// Volume of the current output device and a menu to switch devices (AirPods, speakers, AirPlay).
struct VolumeRow: View {
    let output: AudioOutput
    let devices: [AudioOutputDevice]
    let onVolume: (Double) -> Void
    let onSelect: (AudioOutputDevice) -> Void
    @State private var dragVolume: Double?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: output.volumeSymbol)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
                .accessibilityHidden(true)

            if let volume = output.volume {
                bar(volume: dragVolume ?? Double(output.isMuted ? 0 : volume))
            } else {
                Text("Lautstärke am Gerät regeln")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            deviceMenu
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.islandSecondary)
    }

    private func bar(volume: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.islandTrack)
                Capsule().fill(Color.islandPrimary)
                    .frame(width: max(proxy.size.width * volume, 6))
            }
            .frame(height: dragVolume == nil ? 5 : 8)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged {
                        let value = min(max($0.location.x / proxy.size.width, 0), 1)
                        dragVolume = value
                        onVolume(value)
                    }
                    .onEnded { _ in dragVolume = nil }
            )
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.15), value: dragVolume == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lautstärke")
        .accessibilityValue("\(Int((volume * 100).rounded())) %")
        .accessibilityAdjustableAction { direction in
            onVolume(volume + (direction == .increment ? 0.0625 : -0.0625))
        }
    }

    private var deviceMenu: some View {
        Menu {
            ForEach(devices) { device in
                Button {
                    onSelect(device)
                } label: {
                    Label(device.name, systemImage: device.id == output.device.id ? "checkmark" : device.symbol)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: output.device.symbol)
                Text(output.device.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.islandSecondary)
            .frame(maxWidth: 150, alignment: .trailing)
            .frame(minHeight: Theme.minTapSize - 18)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .layoutPriority(1)
        .help("Ausgabegerät wählen")
        .accessibilityLabel("Ausgabegerät: \(output.device.name)")
    }
}
