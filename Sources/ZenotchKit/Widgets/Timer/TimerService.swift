import AppKit
import Observation

@MainActor
@Observable
final class TimerService {
    static let presets: [TimeInterval] = [5 * 60, 15 * 60, 25 * 60, 50 * 60]

    private(set) var timer = CountdownTimer()
    /// Refreshed every second while running so views re-render.
    private(set) var now = Date()
    private(set) var finishedFlash = false

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var flashTask: Task<Void, Never>?

    var remaining: TimeInterval { timer.remaining(now: now) }
    var progress: Double { timer.progress(now: now) }

    func start(_ duration: TimeInterval) {
        finishedFlash = false
        timer.start(duration: duration, now: Date())
        startTicking()
    }

    func togglePause() {
        let date = Date()
        if timer.isRunning {
            timer.pause(now: date)
            stopTicking()
        } else {
            timer.resume(now: date)
            startTicking()
        }
        now = date
    }

    func addMinute() {
        timer.add(60, now: Date())
        if timer.isRunning { startTicking() }
        now = Date()
    }

    func cancel() {
        timer.cancel()
        stopTicking()
        now = Date()
    }

    private func startTicking() {
        guard ticker == nil else { return }
        now = Date()
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        ticker.tolerance = 0.1
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        guard timer.isFinished(now: now) else { return }
        timer.cancel()
        stopTicking()
        NSSound(named: "Glass")?.play()
        flashTask?.cancel()
        finishedFlash = true
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.finishedFlash = false
        }
    }

    func dismissFinished() {
        flashTask?.cancel()
        finishedFlash = false
    }
}
