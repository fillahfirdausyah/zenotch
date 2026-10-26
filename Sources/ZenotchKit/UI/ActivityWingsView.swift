import SwiftUI

/// Content shown beside the hardware notch while collapsed. The middle stays empty
/// because the camera housing covers it.
struct ActivityWingsView: View {
    let activity: LiveActivity
    let app: AppModel
    let notchWidth: CGFloat
    let wingWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: wingWidth - 14, alignment: .leading)
                .padding(.leading, 14)
            Color.clear.frame(width: notchWidth)
            trailing
                .frame(width: wingWidth - 14, alignment: .trailing)
                .padding(.trailing, 14)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .media:
            if let artwork = app.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                wingSymbol("music.note", color: Style.primary)
            }
        case .timer:
            wingSymbol("timer", color: .orange)
        case .timerFinished:
            wingSymbol("bell.fill", color: .orange)
        case .charging:
            wingSymbol("bolt.fill", color: .green)
        case let .hud(flash):
            wingSymbol(Self.hudSymbol(flash), color: Style.primary)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .media:
            EqualizerBars(isPlaying: app.nowPlaying.isPlaying)
        case .timer:
            Text(TimeFormat.clock(app.timer.remaining))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.orange)
        case .timerFinished:
            Text("Done").font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
        case let .charging(percent):
            Text("\(percent)%").font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.green)
        case let .hud(flash):
            LevelBar(level: flash.muted ? 0 : flash.level)
                .frame(width: 44, height: 5)
        }
    }

    private func wingSymbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
    }

    static func hudSymbol(_ flash: HUDFlash) -> String {
        switch flash.kind {
        case .brightness:
            return flash.level < 0.35 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            if flash.muted || flash.level <= 0.001 { return "speaker.slash.fill" }
            if flash.level < 0.34 { return "speaker.wave.1.fill" }
            if flash.level < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        }
    }
}

struct LevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Style.stroke)
                Capsule().fill(Style.primary).frame(width: proxy.size.width * min(1, max(0, level)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

/// Moving bars signal that audio is actually playing; they rest flat when paused.
/// Core Animation layers animate in the render server, so the app does no per-frame work.
struct EqualizerBars: NSViewRepresentable {
    let isPlaying: Bool

    func makeNSView(context: Context) -> EqualizerNSView { EqualizerNSView() }

    func updateNSView(_ view: EqualizerNSView, context: Context) {
        view.setPlaying(isPlaying)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EqualizerNSView, context: Context) -> CGSize? {
        CGSize(width: 16, height: 14)
    }
}

final class EqualizerNSView: NSView {
    private static let durations: [CFTimeInterval] = [0.42, 0.31, 0.53, 0.37]
    private static let peaks: [CGFloat] = [0.75, 1, 0.6, 0.85]
    private var bars: [CALayer] = []
    private var playing: Bool?

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 16, height: 14))
        wantsLayer = true
        for index in 0..<4 {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = 1.25
            bar.frame = CGRect(x: CGFloat(index) * 4.5, y: 0, width: 2.5, height: 14)
            bar.transform = CATransform3DMakeScale(1, 0.22, 1)
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setPlaying(_ playing: Bool) {
        guard playing != self.playing else { return }
        self.playing = playing
        for (index, bar) in bars.enumerated() {
            bar.removeAllAnimations()
            guard playing else { continue }
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 0.22
            animation.toValue = Self.peaks[index]
            animation.duration = Self.durations[index]
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(animation, forKey: "level")
        }
    }
}
