import AppKit
import Observation

/// Text-only clipboard history kept in memory; nothing is written to disk.
@MainActor
@Observable
final class ClipboardService {
    private(set) var history = ClipboardHistory()

    @ObservationIgnored private var poller: Timer?
    @ObservationIgnored private var lastChangeCount = NSPasteboard.general.changeCount
    @ObservationIgnored private var ownWriteChangeCount: Int?

    var isRunning: Bool { poller != nil }

    /// NSPasteboard has no change notification, so poll its change counter.
    func start() {
        guard poller == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let poller = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poller.tolerance = 0.25
        RunLoop.main.add(poller, forMode: .common)
        self.poller = poller
    }

    func stop() {
        poller?.invalidate()
        poller = nil
    }

    func copy(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        ownWriteChangeCount = pasteboard.changeCount
        history.record(entry.text, at: Date())
    }

    func remove(_ entry: ClipboardEntry) { history.remove(id: entry.id) }
    func clear() { history.clear() }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if ownWriteChangeCount == pasteboard.changeCount { return }
        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard ClipboardHistory.shouldRecord(types: types),
              let text = pasteboard.string(forType: .string)
        else { return }
        history.record(text, at: Date())
    }
}
