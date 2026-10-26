import Foundation

struct BatteryInfo: Equatable {
    var percent: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    var isCharged: Bool
    /// Minutes; nil while macOS is still calculating.
    var minutesRemaining: Int?

    /// Parses an IOPSGetPowerSourceDescription dictionary. Returns nil for non-battery sources.
    init?(description: [String: Any]) {
        guard (description["Type"] as? String) == "InternalBattery" || description["Current Capacity"] != nil,
              let current = description["Current Capacity"] as? Int,
              let max = description["Max Capacity"] as? Int, max > 0
        else { return nil }
        percent = Int((Double(current) / Double(max) * 100).rounded())
        isCharging = description["Is Charging"] as? Bool ?? false
        isPluggedIn = (description["Power Source State"] as? String) == "AC Power"
        isCharged = description["Is Charged"] as? Bool ?? false
        let key = isCharging ? "Time to Full Charge" : "Time to Empty"
        if let minutes = description[key] as? Int, minutes > 0 { minutesRemaining = minutes } else { minutesRemaining = nil }
    }

    var statusText: String {
        if isCharged || (isPluggedIn && percent >= 100) { return "Charged" }
        if isCharging {
            guard let minutesRemaining else { return "Charging" }
            return "Full in \(Self.duration(minutesRemaining))"
        }
        if isPluggedIn { return "Plugged in, not charging" }
        guard let minutesRemaining else { return "On battery" }
        return "\(Self.duration(minutesRemaining)) left"
    }

    static func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
