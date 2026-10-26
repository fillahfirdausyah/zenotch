import Foundation
import IOKit.ps
import Observation

@MainActor
@Observable
final class BatteryService {
    private(set) var info: BatteryInfo?
    /// Set briefly when the charger is connected, to show a live activity.
    private(set) var chargingFlash = false

    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var flashTask: Task<Void, Never>?

    func start() {
        guard source == nil else { return }
        refresh(initial: true)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let loopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.refresh(initial: false) }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .defaultMode)
        source = loopSource
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
    }

    private func refresh(initial: Bool) {
        let previous = info
        info = Self.read()
        guard !initial, let info, let previous else { return }
        if info.isPluggedIn && !previous.isPluggedIn { flash() }
    }

    private func flash() {
        flashTask?.cancel()
        chargingFlash = true
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.chargingFlash = false
        }
    }

    private static func read() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            if let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
               let info = BatteryInfo(description: description) {
                return info
            }
        }
        return nil
    }
}
