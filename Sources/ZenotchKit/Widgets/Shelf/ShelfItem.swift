import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Bookmark data so items survive the file being renamed or moved.
    var bookmark: Data
    var addedAt: Date

    init(id: UUID = UUID(), name: String, bookmark: Data, addedAt: Date) {
        self.id = id
        self.name = name
        self.bookmark = bookmark
        self.addedAt = addedAt
    }

    init?(url: URL, addedAt: Date = Date()) {
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return nil }
        self.init(name: url.lastPathComponent, bookmark: data, addedAt: addedAt)
    }

    func resolveURL() -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }
}

/// Shelf contents persisted as JSON. Pure value type; ShelfStore handles I/O.
struct ShelfContents: Codable, Equatable {
    var items: [ShelfItem] = []

    /// Dropping a file that is already on the shelf moves it to the front.
    mutating func add(_ item: ShelfItem, resolving: (ShelfItem) -> URL?) {
        let newURL = resolving(item)?.standardizedFileURL
        if let newURL {
            items.removeAll { resolving($0)?.standardizedFileURL == newURL }
        }
        items.insert(item, at: 0)
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Drops entries whose file no longer exists.
    mutating func prune(resolving: (ShelfItem) -> URL?) {
        items.removeAll { resolving($0) == nil }
    }
}
