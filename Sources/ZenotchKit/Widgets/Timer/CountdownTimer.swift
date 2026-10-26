import Foundation

/// Countdown state that depends only on the clock passed in, so it is deterministic in tests.
struct CountdownTimer: Equatable {
    enum Phase: Equatable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
    }

    private(set) var phase: Phase = .idle
    private(set) var duration: TimeInterval = 0

    var isActive: Bool { phase != .idle }
    var isRunning: Bool { if case .running = phase { true } else { false } }

    mutating func start(duration: TimeInterval, now: Date) {
        guard duration > 0 else { return }
        self.duration = duration
        phase = .running(endDate: now.addingTimeInterval(duration))
    }

    mutating func pause(now: Date) {
        guard case let .running(endDate) = phase else { return }
        phase = .paused(remaining: max(0, endDate.timeIntervalSince(now)))
    }

    mutating func resume(now: Date) {
        guard case let .paused(remaining) = phase, remaining > 0 else { return }
        phase = .running(endDate: now.addingTimeInterval(remaining))
    }

    mutating func add(_ seconds: TimeInterval, now: Date) {
        switch phase {
        case .idle:
            start(duration: seconds, now: now)
        case let .running(endDate):
            duration += seconds
            phase = .running(endDate: endDate.addingTimeInterval(seconds))
        case let .paused(remaining):
            duration += seconds
            phase = .paused(remaining: remaining + seconds)
        }
    }

    mutating func cancel() {
        phase = .idle
        duration = 0
    }

    func remaining(now: Date) -> TimeInterval {
        switch phase {
        case .idle: 0
        case let .running(endDate): max(0, endDate.timeIntervalSince(now))
        case let .paused(remaining): remaining
        }
    }

    func progress(now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(now: now) / duration))
    }

    func isFinished(now: Date) -> Bool {
        if case .running = phase { return remaining(now: now) <= 0 }
        return false
    }
}
