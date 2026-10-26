import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    let app: AppModel
    let onDisplaysChanged: () -> Void

    var body: some View {
        TabView {
            GeneralSettings(settings: settings, app: app, onDisplaysChanged: onDisplaysChanged)
                .tabItem { Label("General", systemImage: "gearshape") }
            WidgetSettings(settings: settings, app: app)
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            WeatherSettings(settings: settings, service: app.weather)
                .tabItem { Label("Weather", systemImage: "cloud.sun") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 400)
    }
}

private struct GeneralSettings: View {
    @Bindable var settings: SettingsStore
    let app: AppModel
    let onDisplaysChanged: () -> Void

    @ViewState private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @ViewState private var launchError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Zenotch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Behavior") {
                Toggle("Open fully on hover (instead of on click)", isOn: $settings.openOnHover)
                LabeledContent("Hover delay") {
                    HStack {
                        Slider(value: $settings.hoverDelay, in: 0...0.6, step: 0.05)
                        Text("\(Int(settings.hoverDelay * 1000)) ms").monospacedDigit().frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Haptic feedback when opening", isOn: $settings.hapticFeedback)
                Toggle("Show a notch on displays without one", isOn: $settings.showOnExternalDisplays)
                    .onChange(of: settings.showOnExternalDisplays) { _, _ in onDisplaysChanged() }
            }
            Section("Live activities") {
                Toggle("Show activity beside the notch", isOn: $settings.showLiveActivities)
                    .onChange(of: settings.showLiveActivities) { _, _ in app.applySettings() }
                Toggle("Show volume and brightness changes", isOn: $settings.showHUD)
                    .onChange(of: settings.showHUD) { _, _ in app.applySettings() }
                    .disabled(!settings.showLiveActivities)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchError = nil
        } catch {
            launchError = "Could not change login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct WidgetSettings: View {
    @Bindable var settings: SettingsStore
    let app: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(Widget.allCases) { widget in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(widget) },
                        set: { enabled in
                            settings.setEnabled(widget, enabled)
                            app.applySettings()
                        }
                    )) {
                        Label(widget.title, systemImage: widget.symbol)
                    }
                }
            } footer: {
                Text("Battery shows in the header of the open notch and as a charging activity.")
            }
            Section("Clipboard") {
                Toggle("Record copied text", isOn: $settings.recordClipboard)
                    .onChange(of: settings.recordClipboard) { _, _ in app.applySettings() }
                Text("History stays in memory and is cleared when Zenotch quits. Items marked as concealed by password managers are skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct WeatherSettings: View {
    @Bindable var settings: SettingsStore
    let service: WeatherService

    @ViewState private var query = ""
    @ViewState private var results: [WeatherService.Place] = []
    @ViewState private var searching = false
    @ViewState private var searchError: String?

    var body: some View {
        Form {
            Section("Location") {
                LabeledContent("Using") {
                    Text(settings.weatherLatitude == nil ? "Current location" : settings.weatherPlaceName)
                }
                if settings.weatherLatitude != nil {
                    Button("Use Current Location") {
                        settings.weatherLatitude = nil
                        settings.weatherLongitude = nil
                        settings.weatherPlaceName = ""
                        service.refresh()
                    }
                }
                HStack {
                    TextField("Search for a city", text: $query)
                        .onSubmit(search)
                    Button("Search", action: search).disabled(query.trimmingCharacters(in: .whitespaces).count < 2)
                }
                if searching {
                    ProgressView().controlSize(.small)
                } else if let searchError {
                    Text(searchError).font(.caption).foregroundStyle(.red)
                }
                ForEach(results) { place in
                    Button(place.displayName) { choose(place) }
                        .buttonStyle(.link)
                }
            }
            Section("Units") {
                Toggle("Use Fahrenheit", isOn: $settings.useFahrenheit)
                    .onChange(of: settings.useFahrenheit) { _, _ in service.refresh() }
            }
        }
        .formStyle(.grouped)
    }

    private func search() {
        searching = true
        searchError = nil
        Task {
            do {
                results = try await service.search(query)
                if results.isEmpty { searchError = "No places found for \"\(query)\"." }
            } catch {
                searchError = "Search failed. Check your connection."
            }
            searching = false
        }
    }

    private func choose(_ place: WeatherService.Place) {
        settings.weatherPlaceName = place.name
        settings.weatherLatitude = place.latitude
        settings.weatherLongitude = place.longitude
        results = []
        query = ""
        service.refresh()
    }
}

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Zenotch").font(.system(size: 22, weight: .semibold))
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Turns the MacBook notch into a place for music, events, files and timers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Link("Weather data by Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
                .font(.caption)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
