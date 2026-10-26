import Foundation

/// One line of JSON emitted by Bridge/MediaRemoteBridge.m.
struct NowPlayingSnapshot: Decodable, Equatable {
    var pid: Int32
    var playing: Bool
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var elapsed: Double?
    var rate: Double?
    var timestamp: Double?
    var artwork: String?
    var artworkUnchanged: Bool?

    var hasTrack: Bool { pid != 0 && !(title ?? "").isEmpty }

    var artworkData: Data? { artwork.flatMap { Data(base64Encoded: $0) } }

    /// MediaRemote reports elapsed time as of `timestamp`; extrapolate while playing.
    func estimatedElapsed(at now: Date) -> Double? {
        guard let elapsed else { return nil }
        var value = elapsed
        if playing, let timestamp {
            value += max(0, now.timeIntervalSince1970 - timestamp) * (rate ?? 1)
        }
        if let duration, duration > 0 { value = min(value, duration) }
        return max(0, value)
    }

    static func decode(line: Data) -> NowPlayingSnapshot? {
        try? JSONDecoder().decode(NowPlayingSnapshot.self, from: line)
    }
}

enum TimeFormat {
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
