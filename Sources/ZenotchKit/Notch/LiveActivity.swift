import Foundation

public struct HUDFlash: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case volume, brightness }
    public var kind: Kind
    public var level: Double
    public var muted: Bool

    public init(kind: Kind, level: Double, muted: Bool = false) {
        self.kind = kind
        self.level = level
        self.muted = muted
    }
}

/// What the collapsed notch shows in its side "wings".
public enum LiveActivity: Equatable, Sendable {
    case hud(HUDFlash)
    case charging(percent: Int)
    case timerFinished
    case timer
    case media

    /// Transient events win over ongoing ones so a volume change is visible while music plays.
    public static func resolve(
        hud: HUDFlash?,
        chargingFlash: Bool,
        batteryPercent: Int?,
        timerFinishedFlash: Bool,
        timerRunning: Bool,
        mediaPlaying: Bool
    ) -> LiveActivity? {
        if let hud { return .hud(hud) }
        if chargingFlash, let batteryPercent { return .charging(percent: batteryPercent) }
        if timerFinishedFlash { return .timerFinished }
        if timerRunning { return .timer }
        if mediaPlaying { return .media }
        return nil
    }
}
