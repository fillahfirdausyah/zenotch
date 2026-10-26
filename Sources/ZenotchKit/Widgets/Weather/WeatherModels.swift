import Foundation

struct WeatherReport: Equatable {
    var temperature: Double
    var high: Double
    var low: Double
    var code: Int
    var isDay: Bool

    var condition: WeatherCondition { WeatherCondition(code: code) }
}

/// Response shape of api.open-meteo.com/v1/forecast with current + daily fields.
struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        var temperature_2m: Double
        var weather_code: Int
        var is_day: Int
    }

    struct Daily: Decodable {
        var temperature_2m_max: [Double]
        var temperature_2m_min: [Double]
    }

    var current: Current
    var daily: Daily

    var report: WeatherReport? {
        guard let high = daily.temperature_2m_max.first, let low = daily.temperature_2m_min.first else { return nil }
        return WeatherReport(
            temperature: current.temperature_2m,
            high: high,
            low: low,
            code: current.weather_code,
            isDay: current.is_day == 1
        )
    }

    static func url(latitude: Double, longitude: Double, fahrenheit: Bool) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        return components?.url
    }
}

/// WMO weather interpretation codes, as documented by Open-Meteo.
enum WeatherCondition: Equatable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, showers, thunderstorm, unknown

    init(code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51...57: self = .drizzle
        case 61...67: self = .rain
        case 71...77, 85, 86: self = .snow
        case 80...82: self = .showers
        case 95...99: self = .thunderstorm
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .clear: "Clear"
        case .partlyCloudy: "Partly cloudy"
        case .cloudy: "Cloudy"
        case .fog: "Fog"
        case .drizzle: "Drizzle"
        case .rain: "Rain"
        case .snow: "Snow"
        case .showers: "Showers"
        case .thunderstorm: "Thunderstorm"
        case .unknown: "Unknown"
        }
    }

    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .drizzle: "cloud.drizzle.fill"
        case .rain: "cloud.rain.fill"
        case .snow: "cloud.snow.fill"
        case .showers: "cloud.heavyrain.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        case .unknown: "thermometer.medium"
        }
    }
}
