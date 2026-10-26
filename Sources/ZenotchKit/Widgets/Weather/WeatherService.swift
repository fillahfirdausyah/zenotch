import CoreLocation
import Foundation
import Observation

/// Weather from Open-Meteo (no API key). Location is either a city set in Settings
/// or the Mac's current location.
@MainActor
@Observable
final class WeatherService: NSObject {
    enum Status: Equatable {
        case idle
        case loading
        case ready
        case needsLocation
        case failed(String)
    }

    struct Place: Decodable, Equatable, Identifiable {
        var id: Int
        var name: String
        var latitude: Double
        var longitude: Double
        var country: String?
        var admin1: String?

        var displayName: String {
            [name, admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        }
    }

    private(set) var status: Status = .idle
    private(set) var report: WeatherReport?
    private(set) var placeLabel: String?
    private(set) var updatedAt: Date?

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var locationManager: CLLocationManager?
    @ObservationIgnored private var refreshTimer: Timer?

    init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Re-fetches unless the last report is fresh, so opening the notch does not spam the API.
    func refreshIfStale() {
        guard let updatedAt, Date().timeIntervalSince(updatedAt) < 10 * 60 else { return refresh() }
    }

    func refresh() {
        if let latitude = settings.weatherLatitude, let longitude = settings.weatherLongitude {
            placeLabel = settings.weatherPlaceName
            fetch(latitude: latitude, longitude: longitude)
            return
        }
        requestCurrentLocation()
    }

    func search(_ query: String) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "en"),
        ]
        guard let url = components?.url else { return [] }
        struct Response: Decodable { var results: [Place]? }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(Response.self, from: data).results ?? []
    }

    private func requestCurrentLocation() {
        placeLabel = "Current location"
        let manager = locationManager ?? CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager = manager
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .loading
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .needsLocation
        default:
            status = report == nil ? .loading : status
            manager.requestLocation()
        }
    }

    private func fetch(latitude: Double, longitude: Double) {
        guard let url = OpenMeteoResponse.url(latitude: latitude, longitude: longitude, fahrenheit: settings.useFahrenheit) else { return }
        if report == nil { status = .loading }
        Task {
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw URLError(.badServerResponse)
                }
                guard let report = try JSONDecoder().decode(OpenMeteoResponse.self, from: data).report else {
                    throw URLError(.cannotParseResponse)
                }
                self.report = report
                self.updatedAt = Date()
                self.status = .ready
            } catch {
                self.status = .failed(report == nil ? "Weather is unavailable right now." : "Showing the last update.")
            }
        }
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard settings.weatherLatitude == nil else { return }
            switch status {
            case .authorized, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.status = .needsLocation
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            guard settings.weatherLatitude == nil else { return }
            fetch(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            if report == nil { status = .needsLocation }
        }
    }
}
