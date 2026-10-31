import SwiftUI

struct NotchView: View {
    @Bindable var model: NotchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        island
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.78), value: model.mode)
            .preferredColorScheme(.dark)
    }

    private var island: some View {
        let size = model.islandSize
        let radii = model.cornerRadii
        return ZStack(alignment: .top) {
            switch model.mode {
            case .hidden:
                EmptyView()
            case .compact:
                compact.transition(.opacity)
            case .expanded:
                expanded.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Color.island)
        .clipShape(NotchShape(topRadius: radii.top, bottomRadius: radii.bottom))
        .shadow(color: .black.opacity(model.mode == .expanded ? 0.5 : 0), radius: 12, y: 4)
        // Without a hardware notch there is nothing to hide behind, so fade out completely.
        .opacity(model.mode == .hidden && !model.hasNotch ? 0 : 1)
    }

    // MARK: - Compact

    private var compact: some View {
        let artworkSize = model.notchSize.height - 10
        return HStack(spacing: 0) {
            ArtworkView(image: model.artwork, cornerRadius: 6)
                .frame(width: artworkSize, height: artworkSize)
                .frame(width: model.compactWing)
            Spacer(minLength: model.notchSize.width)
            EqualizerView(isPlaying: model.nowPlaying?.isPlaying ?? false, tint: model.tint)
                .frame(width: 18, height: artworkSize * 0.6)
                .frame(width: model.compactWing)
        }
        .frame(height: model.notchSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nowPlayingLabel)
    }

    // MARK: - Expanded

    private var expanded: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Button(action: model.openSource) {
                    ArtworkView(image: model.artwork, cornerRadius: Theme.artworkCornerRadius)
                        .frame(width: 92, height: 92)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quell-App öffnen")
                .help("Quell-App öffnen")

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.nowPlaying?.title ?? "")
                        .font(.islandTitle)
                        .foregroundStyle(Color.islandPrimary)
                    if let album = model.nowPlaying?.album {
                        Text(album)
                            .font(.islandSubtitle)
                            .foregroundStyle(Color.islandSecondary)
                    }
                    if let artist = model.nowPlaying?.artist {
                        Text(artist)
                            .font(.islandSubtitle)
                            .foregroundStyle(Color.islandSecondary)
                    }
                    controls.padding(.top, 2)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                EqualizerView(isPlaying: model.nowPlaying?.isPlaying ?? false, tint: model.tint)
                    .frame(width: 22, height: 18)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            if let nowPlaying = model.nowPlaying, nowPlaying.duration != nil {
                ProgressBar(nowPlaying: nowPlaying) { model.seek(toProgress: $0) }
            }
        }
        .padding(.horizontal, 24 + model.cornerRadii.top)
        .padding(.top, model.notchSize.height + 10)
        .padding(.bottom, 14)
    }

    private var controls: some View {
        HStack(spacing: 4) {
            ControlButton(systemImage: "backward.fill", label: "Zurück", action: model.previous)
            ControlButton(
                systemImage: model.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill",
                label: model.nowPlaying?.isPlaying == true ? "Pause" : "Wiedergabe",
                size: 24,
                action: model.togglePlayPause
            )
            ControlButton(systemImage: "forward.fill", label: "Weiter", action: model.next)
        }
        .padding(.leading, -12)
    }

    private var nowPlayingLabel: String {
        guard let nowPlaying = model.nowPlaying else { return "" }
        return [nowPlaying.title, nowPlaying.artist].compactMap(\.self).joined(separator: ", ")
    }
}

// MARK: - Pieces

private struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.islandSecondary)
                }
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct ControlButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(Color.islandPrimary)
                .frame(width: Theme.minTapSize, height: Theme.minTapSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Four bars that dance while music plays, tinted with the cover color.
struct EqualizerView: View {
    let isPlaying: Bool
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let speeds: [Double] = [5.1, 7.3, 4.2, 6.4]
    private let resting: [Double] = [0.45, 0.8, 0.6, 0.35]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: proxy.size.width * 0.12) {
                    ForEach(speeds.indices, id: \.self) { index in
                        Capsule()
                            .fill(tint)
                            .frame(height: proxy.size.height * level(index, time: time))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .opacity(isPlaying ? 1 : 0.5)
        .animation(.easeOut(duration: 0.3), value: isPlaying)
        .accessibilityHidden(true)
    }

    private func level(_ index: Int, time: TimeInterval) -> Double {
        guard isPlaying, !reduceMotion else { return isPlaying ? resting[index] : 0.25 }
        let wave = sin(time * speeds[index]) * 0.5 + sin(time * speeds[index] * 1.7 + Double(index)) * 0.5
        return 0.25 + 0.75 * (wave * 0.5 + 0.5)
    }
}

private struct ProgressBar: View {
    let nowPlaying: NowPlaying
    let onSeek: (Double) -> Void
    @State private var dragProgress: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let progress = dragProgress ?? nowPlaying.progress(at: context.date) ?? 0
            let duration = nowPlaying.duration ?? 0
            HStack(spacing: 10) {
                Text((progress * duration).playbackTime)
                    .frame(minWidth: 36, alignment: .trailing)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.islandTrack)
                        Capsule().fill(Color.islandPrimary)
                            .frame(width: max(proxy.size.width * progress, 6))
                    }
                    .frame(height: dragProgress == nil ? 5 : 8)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { dragProgress = min(max($0.location.x / proxy.size.width, 0), 1) }
                            .onEnded { _ in
                                if let dragProgress { onSeek(dragProgress) }
                                self.dragProgress = nil
                            }
                    )
                }
                .frame(height: 20)
                Text("-" + ((1 - progress) * duration).playbackTime)
                    .frame(minWidth: 40, alignment: .leading)
            }
            .font(.islandTime)
            .foregroundStyle(Color.islandSecondary)
            .animation(.easeOut(duration: 0.15), value: dragProgress == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wiedergabeposition")
            .accessibilityValue("\((progress * duration).playbackTime) von \(duration.playbackTime)")
            .accessibilityAdjustableAction { direction in
                let step = 10 / max(duration, 1)
                onSeek(progress + (direction == .increment ? step : -step))
            }
        }
    }
}

#if DEBUG
#Preview {
    let model = NotchViewModel(source: DemoNowPlayingSource(), forceExpanded: true)
    model.start()
    return NotchView(model: model).frame(width: 640, height: 240).background(.gray)
}
#endif
