import SwiftUI

struct NotchView: View {
    @Bindable var model: NotchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        island
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(modeAnimation, value: model.mode)
            .animation(.smooth(duration: 0.35), value: model.layout.size.height)
            .preferredColorScheme(.dark)
    }

    /// Opening gets a little bounce, closing settles quickly. Reduce Motion drops the bounce entirely.
    private var modeAnimation: Animation {
        if reduceMotion { return .smooth(duration: 0.25) }
        return model.mode == .expanded ? .spring(duration: 0.5, bounce: 0.28) : .spring(duration: 0.38, bounce: 0.12)
    }

    private var isExpanded: Bool { model.mode == .expanded }

    private var island: some View {
        let layout = model.layout
        let shape = NotchShape(topRadius: layout.topRadius, bottomRadius: layout.bottomRadius)
        return ZStack(alignment: .topLeading) {
            if isExpanded {
                expandedContent(layout)
                    .transition(reduceMotion ? .opacity : .blurFade)
            }
            artwork(layout)
            EqualizerView(isPlaying: model.nowPlaying?.isPlaying ?? false, tint: model.tint)
                .frame(width: layout.equalizer.width, height: layout.equalizer.height)
                .offset(x: layout.equalizer.minX, y: layout.equalizer.minY)
                .opacity(model.mode == .hidden ? 0 : 1)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .background(Color.island)
        .clipShape(shape)
        // Key line in the cover color, like the Dynamic Island's outline in dark surroundings.
        .overlay(shape.stroke(model.tint.opacity(isExpanded ? 0.35 : 0), lineWidth: 1))
        .shadow(color: .black.opacity(isExpanded ? 0.5 : 0), radius: 14, y: 6)
        // Without a hardware notch there is nothing to hide behind, so fade out completely.
        .opacity(model.mode == .hidden && !model.hasNotch ? 0 : 1)
        .accessibilityElement(children: isExpanded ? .contain : .ignore)
        .accessibilityLabel(isExpanded ? "Läuft gerade" : nowPlayingLabel)
    }

    private func artwork(_ layout: NotchLayout) -> some View {
        Button(action: model.openSource) {
            ArtworkView(image: model.artwork, id: model.artworkID, cornerRadius: layout.artworkCornerRadius)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isExpanded)
        .frame(width: layout.artwork.width, height: layout.artwork.height)
        .shadow(color: model.tint.opacity(isExpanded ? 0.45 : 0), radius: 16)
        .offset(x: layout.artwork.minX, y: layout.artwork.minY)
        .opacity(model.mode == .hidden ? 0 : 1)
        .accessibilityLabel("Quell-App öffnen")
        .help("Quell-App öffnen")
    }

    // MARK: - Expanded

    private func expandedContent(_ layout: NotchLayout) -> some View {
        ZStack(alignment: .topLeading) {
            if let icon = model.sourceIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .frame(width: layout.header.width, height: layout.header.height, alignment: .leading)
                    .offset(x: layout.header.minX, y: layout.header.minY)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 1) {
                MarqueeText(text: model.nowPlaying?.title ?? "", font: .islandTitle, isActive: isExpanded)
                    .foregroundStyle(Color.islandPrimary)
                Group {
                    if let album = model.nowPlaying?.album { Text(album) }
                    if let artist = model.nowPlaying?.artist { Text(artist) }
                }
                .font(.islandSubtitle)
                .foregroundStyle(Color.islandSecondary)
                .lineLimit(1)
                Spacer(minLength: 0)
                controls
            }
            .id(model.nowPlaying?.title)
            .transition(reduceMotion ? .opacity : .blurFade)
            .animation(.smooth(duration: 0.3), value: model.nowPlaying?.title)
            .frame(width: layout.text.width, height: layout.text.height, alignment: .topLeading)
            .offset(x: layout.text.minX, y: layout.text.minY)

            if let nowPlaying = model.nowPlaying, nowPlaying.duration != nil {
                ProgressBar(nowPlaying: nowPlaying) { model.seek(toProgress: $0) }
                    .frame(width: layout.progress.width, height: layout.progress.height)
                    .offset(x: layout.progress.minX, y: layout.progress.minY)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 2) {
            ControlButton(systemImage: "backward.fill", label: "Zurück", action: model.previous)
            ControlButton(
                systemImage: model.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill",
                label: model.nowPlaying?.isPlaying == true ? "Pause" : "Wiedergabe",
                size: 22,
                action: model.togglePlayPause
            )
            ControlButton(systemImage: "forward.fill", label: "Weiter", action: model.next)
        }
        .padding(.leading, -12)
        .padding(.bottom, -8)
    }

    private var nowPlayingLabel: String {
        guard let nowPlaying = model.nowPlaying else { return "" }
        return [nowPlaying.title, nowPlaying.artist].compactMap(\.self).joined(separator: ", ")
    }
}

// MARK: - Pieces

private struct ArtworkView: View {
    let image: NSImage?
    /// Changes with each new cover, so the old one crossfades to the new one.
    let id: Int
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
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
            .id(id)
            .transition(.opacity)
        }
        .animation(.smooth(duration: 0.4), value: id)
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct ControlButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = 17
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(Color.islandPrimary)
                .frame(width: Theme.minTapSize, height: Theme.minTapSize)
                .background(Circle().fill(Color.white.opacity(isHovering ? 0.14 : 0)).padding(4))
                .contentShape(.circle)
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.15), value: isHovering)
        .accessibilityLabel(label)
    }
}

/// Shrinks a little while pressed, like system buttons on the Dynamic Island.
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Scrolls a title that does not fit, after a pause, then starts over. Truncates with Reduce Motion.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0

    private let gap: CGFloat = 40
    private let speed: CGFloat = 30
    private let pause: TimeInterval = 2.5

    var body: some View {
        GeometryReader { proxy in
            let overflows = textWidth > proxy.size.width + 1
            if overflows, isActive, !reduceMotion {
                TimelineView(.animation) { context in
                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .offset(x: -offset(at: context.date))
                }
                .frame(width: proxy.size.width, alignment: .leading)
                .clipped()
                .mask(fadeMask)
            } else {
                label.frame(width: proxy.size.width, alignment: .leading)
                    .truncationMode(.tail)
            }
        }
        .frame(height: textHeight)
        .background(
            label.fixedSize().hidden()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { textWidth = $0 }
        )
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    private var label: some View {
        Text(text).font(font).lineLimit(1).fixedSize(horizontal: true, vertical: false)
    }

    private var textHeight: CGFloat { 22 }

    private var fadeMask: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0), .init(color: .black, location: 0.04),
            .init(color: .black, location: 0.9), .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing)
    }

    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        let scroll = TimeInterval(distance / speed)
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: pause + scroll)
        return phase < pause ? 0 : CGFloat(phase - pause) * speed
    }
}

private struct BlurFade: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.blur(radius: active ? 8 : 0).opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    /// Content melts in and out of the island, as on the Dynamic Island.
    static var blurFade: AnyTransition {
        .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
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
