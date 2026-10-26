import Foundation
import Observation

public enum Widget: String, CaseIterable, Identifiable, Codable {
    case nowPlaying, calendar, battery, shelf, timer, clipboard, weather, mirror

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .calendar: "Calendar"
        case .battery: "Battery"
        case .shelf: "Shelf"
        case .timer: "Timer"
        case .clipboard: "Clipboard"
        case .weather: "Weather"
        case .mirror: "Mirror"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .calendar: "calendar"
        case .battery: "battery.75percent"
        case .shelf: "tray"
        case .timer: "timer"
        case .clipboard: "doc.on.clipboard"
        case .weather: "cloud.sun"
        case .mirror: "camera"
        }
    }
}

@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public var enabledWidgets: Set<Widget> { didSet { save(enabledWidgets.map(\.rawValue), "enabledWidgets") } }
    public var openOnHover: Bool { didSet { save(openOnHover, "openOnHover") } }
    public var hoverDelay: Double { didSet { save(hoverDelay, "hoverDelay") } }
    public var showOnExternalDisplays: Bool { didSet { save(showOnExternalDisplays, "showOnExternalDisplays") } }
    public var hapticFeedback: Bool { didSet { save(hapticFeedback, "hapticFeedback") } }
    public var showLiveActivities: Bool { didSet { save(showLiveActivities, "showLiveActivities") } }
    public var showHUD: Bool { didSet { save(showHUD, "showHUD") } }
    public var useFahrenheit: Bool { didSet { save(useFahrenheit, "useFahrenheit") } }
    /// Empty means use the current location.
    public var weatherPlaceName: String { didSet { save(weatherPlaceName, "weatherPlaceName") } }
    public var weatherLatitude: Double? { didSet { saveOptional(weatherLatitude, "weatherLatitude") } }
    public var weatherLongitude: Double? { didSet { saveOptional(weatherLongitude, "weatherLongitude") } }
    public var recordClipboard: Bool { didSet { save(recordClipboard, "recordClipboard") } }
    public var lastTab: Widget { didSet { save(lastTab.rawValue, "lastTab") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = (defaults.array(forKey: "enabledWidgets") as? [String])?.compactMap(Widget.init(rawValue:))
        enabledWidgets = Set(stored ?? [.nowPlaying, .calendar, .battery, .shelf, .timer, .clipboard, .weather])
        openOnHover = defaults.object(forKey: "openOnHover") as? Bool ?? false
        hoverDelay = defaults.object(forKey: "hoverDelay") as? Double ?? 0.15
        showOnExternalDisplays = defaults.object(forKey: "showOnExternalDisplays") as? Bool ?? false
        hapticFeedback = defaults.object(forKey: "hapticFeedback") as? Bool ?? true
        showLiveActivities = defaults.object(forKey: "showLiveActivities") as? Bool ?? true
        showHUD = defaults.object(forKey: "showHUD") as? Bool ?? true
        useFahrenheit = defaults.object(forKey: "useFahrenheit") as? Bool ?? false
        weatherPlaceName = defaults.string(forKey: "weatherPlaceName") ?? ""
        weatherLatitude = defaults.object(forKey: "weatherLatitude") as? Double
        weatherLongitude = defaults.object(forKey: "weatherLongitude") as? Double
        recordClipboard = defaults.object(forKey: "recordClipboard") as? Bool ?? true
        lastTab = (defaults.string(forKey: "lastTab")).flatMap(Widget.init(rawValue:)) ?? .nowPlaying
    }

    /// Tabs in display order. Battery lives in the header rather than its own tab.
    var tabs: [Widget] {
        Widget.allCases.filter { enabledWidgets.contains($0) && $0 != .battery }
    }

    func isEnabled(_ widget: Widget) -> Bool { enabledWidgets.contains(widget) }

    func setEnabled(_ widget: Widget, _ enabled: Bool) {
        if enabled { enabledWidgets.insert(widget) } else { enabledWidgets.remove(widget) }
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private func saveOptional(_ value: Double?, _ key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}
