import SwiftUI

struct TimerView: View {
    let service: TimerService

    @ViewState private var customMinutes = 10

    var body: some View {
        if service.timer.isActive {
            running
        } else {
            picker
        }
    }

    private var running: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle().stroke(Style.stroke, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: 1 - service.progress)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: service.progress)
                Text(TimeFormat.clock(service.remaining))
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Style.primary)
            }
            .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 10) {
                Text(service.timer.isRunning ? "Running" : "Paused")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Style.secondary)
                HStack(spacing: 8) {
                    PillButton(title: service.timer.isRunning ? "Pause" : "Resume", symbol: service.timer.isRunning ? "pause.fill" : "play.fill", prominent: true, action: service.togglePause)
                    PillButton(title: "1 min", symbol: "plus", action: service.addMinute)
                    PillButton(title: "Cancel", action: service.cancel)
                }
            }
            Spacer()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 14) {
            if service.finishedFlash {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill").foregroundStyle(.orange)
                    Text("Time's up").font(.system(size: 13, weight: .semibold)).foregroundStyle(Style.primary)
                    PillButton(title: "Dismiss", action: service.dismissFinished)
                }
            }
            Text("Start a timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Style.secondary)
            HStack(spacing: 8) {
                ForEach(TimerService.presets, id: \.self) { preset in
                    PresetButton(minutes: Int(preset / 60)) { service.start(preset) }
                }
            }
            HStack(spacing: 10) {
                Stepper(value: $customMinutes, in: 1...240) {
                    Text("\(customMinutes) min")
                        .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(Style.primary)
                        .frame(width: 60, alignment: .leading)
                }
                .fixedSize()
                PillButton(title: "Start", symbol: "play.fill", prominent: true) {
                    service.start(TimeInterval(customMinutes * 60))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PresetButton: View {
    let minutes: Int
    let action: () -> Void

    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(minutes)").font(.system(size: 22, weight: .semibold).monospacedDigit())
                Text("min").font(.system(size: 11)).foregroundStyle(Style.secondary)
            }
            .foregroundStyle(Style.primary)
            .frame(width: 72, height: 56)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Style.fillHover : Style.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Start \(minutes) minute timer")
    }
}
