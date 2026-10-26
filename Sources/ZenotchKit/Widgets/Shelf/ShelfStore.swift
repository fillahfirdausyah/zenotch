import AppKit
import Observation

@MainActor
@Observable
final class ShelfStore {
    private(set) var contents = ShelfContents()
    private(set) var lastError: String?

    @ObservationIgnored private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zenotch", isDirectory: true)
        fileURL = base.appendingPathComponent("shelf.json")
        load()
    }

    var items: [ShelfItem] { contents.items }

    func add(urls: [URL]) {
        var added = 0
        for url in urls where url.isFileURL {
            guard let item = ShelfItem(url: url) else { continue }
            contents.add(item) { $0.resolveURL() }
            added += 1
        }
        lastError = added == 0 && !urls.isEmpty ? "Those items could not be added." : nil
        save()
    }

    func remove(_ item: ShelfItem) {
        contents.remove(id: item.id)
        save()
    }

    func clear() {
        contents = ShelfContents()
        save()
    }

    func open(_ item: ShelfItem) {
        guard let url = item.resolveURL() else { return missing(item) }
        NSWorkspace.shared.open(url)
    }

    func reveal(_ item: ShelfItem) {
        guard let url = item.resolveURL() else { return missing(item) }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func icon(for item: ShelfItem) -> NSImage {
        guard let url = item.resolveURL() else { return NSImage(systemSymbolName: "questionmark.folder", accessibilityDescription: nil) ?? NSImage() }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func pruneMissing() {
        let before = contents.items.count
        contents.prune { $0.resolveURL() }
        if contents.items.count != before { save() }
    }

    private func missing(_ item: ShelfItem) {
        lastError = "\(item.name) was moved or deleted."
        contents.remove(id: item.id)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(ShelfContents.self, from: data) {
            contents = decoded
        } else {
            lastError = "The saved shelf could not be read and was reset."
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(contents).write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Could not save the shelf: \(error.localizedDescription)"
        }
    }
}
