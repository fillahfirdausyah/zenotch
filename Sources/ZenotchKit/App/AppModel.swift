import AppKit
import Observation

/// Shared state for every notch window: settings, services and the selected tab.
@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let nowPlaying = NowPlayingService()
    let battery = BatteryService()
    let calendar = CalendarService()
    let timer = TimerService()
    let clipboard = ClipboardService()
    let shelf = ShelfStore()
    let mirror = MirrorService()
    let hud = HUDService()
    let weather: WeatherService

    var selectedTab: Widget

    init(settings: SettingsStore) {
        self.settings = settings
        weather = WeatherService(settings: settings)
        selectedTab = settings.lastTab
    }

    var tabs: [Widget] { settings.tabs }

    /// The tab to show, falling back when the remembered one was disabled.
    var visibleTab: Widget? {
        tabs.contains(selectedTab) ? selectedTab : tabs.first
    }

    var liveActivity: LiveActivity? {
        guard settings.showLiveActivities else { return nil }
        return LiveActivity.resolve(
            hud: settings.showHUD ? hud.flash : nil,
            chargingFlash: settings.isEnabled(.battery) && battery.chargingFlash,
            batteryPercent: battery.info?.percent,
            timerFinishedFlash: settings.isEnabled(.timer) && timer.finishedFlash,
            timerRunning: settings.isEnabled(.timer) && timer.timer.isRunning,
            mediaPlaying: settings.isEnabled(.nowPlaying) && nowPlaying.isPlaying
        )
    }

    func selectTab(_ tab: Widget) {
        guard settings.isEnabled(tab) else { return }
        selectedTab = tab
        settings.lastTab = tab
    }

    func startServices() {
        battery.start()
        applySettings()
    }

    /// Starts or stops services so disabled widgets cost nothing.
    func applySettings() {
        let s = settings
        if s.isEnabled(.nowPlaying) { nowPlaying.start() } else { nowPlaying.stop() }
        if s.isEnabled(.calendar) { calendar.start() }
        if s.isEnabled(.clipboard) && s.recordClipboard { clipboard.start() } else { clipboard.stop() }
        if s.isEnabled(.weather) { weather.start() } else { weather.stop() }
        if s.showHUD && s.showLiveActivities { hud.start() } else { hud.stop() }
        if !s.isEnabled(.mirror) { mirror.stop() }
    }

    func notchDidExpand() {
        if settings.isEnabled(.calendar), calendar.status == .ready { calendar.reload() }
        if settings.isEnabled(.weather) { weather.refreshIfStale() }
        if settings.isEnabled(.shelf) { shelf.pruneMissing() }
    }

    func stopServices() {
        nowPlaying.stop()
        clipboard.stop()
        weather.stop()
        hud.stop()
        mirror.stop()
        battery.stop()
    }
}
