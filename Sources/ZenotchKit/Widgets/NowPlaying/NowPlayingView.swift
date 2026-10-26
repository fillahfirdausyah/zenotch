import SwiftUI

struct NowPlayingView: View {
    let service: NowPlayingService

    var body: some View {
        switch service.status {
        case let .unavailable(reason):
            WidgetMessage(symbol: "exclamationmark.triangle", title: "Now Playing is unavailable", detail: reason)
        case .starting:
            LoadingMessage(title: "Connecting to media")
        case .running:
            if let snapshot = service.snapshot, snapshot.hasTrack {
                player(snapshot)
            } else if service.snapshot == nil {
                LoadingMessage(title: "Connecting to media")
            } else {
                WidgetMessage(
                    symbol: "music.note",
                    title: "Nothing playing",
                    detail: "Play something in Music, Spotify or a browser and it shows up here."
                )
            }
        }
    }

    private func player(_ snapshot: NowPlayingSnapshot) -> some View {
        HStack(spacing: 18) {
            Button(action: service.openSourceApp) {
                artwork
            }
            .buttonStyle(.plain)
            .help(service.sourceApp?.localizedName.map { "Open \($0)" } ?? "Open player")

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.title ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Style.primary)
                        .lineLimit(1)
                    Text([snapshot.artist, snapshot.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Style.secondary)
                        .lineLimit(1)
                }
                ProgressScrubber(snapshot: snapshot, onSeek: service.seek(to:))
                HStack(spacing: 22) {
                    IconButton(symbol: "backward.fill", label: "Previous track", size: 32, font: .system(size: 16, weight: .semibold), action: service.previous)
                    IconButton(
                        symbol: snapshot.playing ? "pause.fill" : "play.fill",
                        label: snapshot.playing ? "Pause" : "Play",
                        size: 38,
                        font: .system(size: 22, weight: .semibold),
                        action: service.togglePlayPause
                    )
                    IconButton(symbol: "forward.fill", label: "Next track", size: 32, font: .system(size: 16, weight: .semibold), action: service.next)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var artwork: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = service.artwork {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Style.fill
                        Image(systemName: "music.note").font(.system(size: 34)).foregroundStyle(Style.tertiary)
                    }
                }
            }
            .frame(width: 128, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let icon = service.sourceApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .offset(x: 6, y: 6)
            }
        }
    }
}

/// Elapsed time is extrapolated locally, so the bar moves without polling the bridge.
private struct ProgressScrubber: View {
    let snapshot: NowPlayingSnapshot
    let onSeek: (Double) -> Void

    @ViewState private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: snapshot.playing ? 0.5 : 3600)) { context in
            let duration = snapshot.duration ?? 0
            let elapsed = snapshot.estimatedElapsed(at: context.date) ?? 0
            let fraction = dragFraction ?? (duration > 0 ? elapsed / duration : 0)
            HStack(spacing: 10) {
                Text(TimeFormat.clock(dragFraction.map { $0 * duration } ?? elapsed))
                    .lineLimit(1)
                    .frame(width: 52, alignment: .trailing)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Style.stroke)
                        Capsule().fill(Style.primary).frame(width: max(0, proxy.size.width * fraction))
                    }
                    .frame(height: dragFraction == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(duration > 0 ? scrub(width: proxy.size.width, duration: duration) : nil)
                }
                .frame(height: 14)
                Text(duration > 0 ? TimeFormat.clock(duration) : "--:--")
                    .lineLimit(1)
                    .frame(width: 52, alignment: .leading)
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(Style.secondary)
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
    }

    private func scrub(width: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragFraction = min(1, max(0, value.location.x / max(1, width)))
            }
            .onEnded { value in
                let fraction = min(1, max(0, value.location.x / max(1, width)))
                onSeek(fraction * duration)
                // Hold the dragged position until the bridge reports the new elapsed time.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dragFraction = nil }
            }
    }
}
