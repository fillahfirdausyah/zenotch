import AppKit
import EventKit
import Observation

@MainActor
@Observable
final class CalendarService {
    enum Status: Equatable {
        case notDetermined
        case loading
        case ready
        case denied
        case failed(String)
    }

    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: NSColor
        let location: String?
    }

    private(set) var status: Status = .notDetermined
    private(set) var events: [Event] = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var dayObserver: NSObjectProtocol?

    func start() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            observeChanges()
            reload()
        case .denied, .restricted, .writeOnly:
            status = .denied
        default:
            status = .notDetermined
        }
    }

    func requestAccess() {
        status = .loading
        store.requestFullAccessToEvents { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = .failed(error.localizedDescription)
                } else if granted {
                    self.observeChanges()
                    self.reload()
                } else {
                    self.status = .denied
                }
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarApp(at date: Date) {
        // ical:// with a timestamp opens Calendar on that day.
        let seconds = Int(date.timeIntervalSinceReferenceDate)
        if let url = URL(string: "ical://\(seconds)") { NSWorkspace.shared.open(url) }
    }

    func reload() {
        if events.isEmpty { status = .loading }
        let now = Date()
        let calendar = Calendar.current
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) ?? now
        let predicate = store.predicateForEvents(withStart: calendar.startOfDay(for: now), end: endOfTomorrow, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
            .prefix(8)
            .map {
                Event(
                    id: $0.calendarItemIdentifier + "\($0.startDate.timeIntervalSince1970)",
                    title: $0.title ?? "Untitled",
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    color: $0.calendar.color ?? .systemBlue,
                    location: $0.location
                )
            }
        status = .ready
    }

    private func observeChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        dayObserver = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }
}
