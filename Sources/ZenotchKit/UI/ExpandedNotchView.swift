import SwiftUI

struct ExpandedNotchView: View {
    let model: NotchViewModel

    private var app: AppModel { model.app }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: model.notchRect.height)
            Group {
                if let tab = app.visibleTab {
                    widget(for: tab)
                } else {
                    WidgetMessage(
                        symbol: "square.grid.2x2",
                        title: "No widgets turned on",
                        detail: "Choose which widgets to show in Settings.",
                        actionTitle: "Open Settings",
                        action: { SettingsWindowController.shared?.show() }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The header row shares its height with the hardware notch, so nothing is placed in the middle.
    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 1) {
                ForEach(app.tabs) { tab in
                    IconButton(symbol: tab.symbol, label: tab.title, size: 24, isSelected: app.visibleTab == tab) {
                        app.selectTab(tab)
                    }
                }
            }
            .padding(.leading, 12)
            Spacer(minLength: model.notchRect.width + 12)
            HStack(spacing: 8) {
                if app.settings.isEnabled(.battery), let info = app.battery.info {
                    BatteryBadge(info: info)
                }
                IconButton(symbol: "gearshape", label: "Settings", size: 24) {
                    SettingsWindowController.shared?.show()
                }
            }
            .padding(.trailing, 12)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func widget(for tab: Widget) -> some View {
        switch tab {
        case .nowPlaying: NowPlayingView(service: app.nowPlaying)
        case .calendar: CalendarView(service: app.calendar)
        case .shelf: ShelfView(store: app.shelf, isDropTargeted: model.isDropTargeted)
        case .timer: TimerView(service: app.timer)
        case .clipboard: ClipboardView(service: app.clipboard, settings: app.settings, onEnable: app.applySettings)
        case .weather: WeatherView(service: app.weather, settings: app.settings)
        case .mirror: MirrorView(service: app.mirror)
        case .battery: EmptyView()
        }
    }
}
