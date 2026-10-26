import SwiftUI

struct WeatherView: View {
    let service: WeatherService
    let settings: SettingsStore

    var body: some View {
        switch (service.status, service.report) {
        case let (_, report?):
            content(report)
        case (.needsLocation, nil):
            WidgetMessage(
                symbol: "location.slash",
                title: "Location is off",
                detail: "Allow location for Zenotch, or pick a city in Settings.",
                actionTitle: "Choose a City",
                action: { SettingsWindowController.shared?.show() }
            )
        case let (.failed(message), nil):
            WidgetMessage(symbol: "wifi.exclamationmark", title: "No weather", detail: message, actionTitle: "Try Again", action: service.refresh)
        default:
            LoadingMessage(title: "Loading weather")
        }
    }

    private func content(_ report: WeatherReport) -> some View {
        HStack(spacing: 24) {
            Image(systemName: report.condition.symbol(isDay: report.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 64))
                .frame(width: 100)
            VStack(alignment: .leading, spacing: 4) {
                Text(degrees(report.temperature))
                    .font(.system(size: 44, weight: .medium).monospacedDigit())
                    .foregroundStyle(Style.primary)
                Text(report.condition.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Style.primary)
                Text("High \(degrees(report.high))  Low \(degrees(report.low))")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Style.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let place = service.placeLabel, !place.isEmpty {
                    Label(place, systemImage: settings.weatherLatitude == nil ? "location.fill" : "mappin")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.secondary)
                        .lineLimit(1)
                }
                if case let .failed(message) = service.status {
                    Text(message).font(.system(size: 11)).foregroundStyle(.orange)
                } else if let updated = service.updatedAt {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(Style.tertiary)
                }
                IconButton(symbol: "arrow.clockwise", label: "Refresh weather", action: service.refresh)
                Spacer()
                Link("Weather data by Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
                    .font(.system(size: 10))
                    .foregroundStyle(Style.tertiary)
            }
        }
    }

    private func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }
}
