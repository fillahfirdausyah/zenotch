import SwiftUI

struct CalendarView: View {
    let service: CalendarService

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            DateBlock(onOpen: { service.openCalendarApp(at: Date()) })
            Divider().overlay(Style.stroke)
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.status {
        case .notDetermined:
            WidgetMessage(
                symbol: "calendar.badge.plus",
                title: "See today's events here",
                detail: "Zenotch reads your calendars on this Mac. Nothing leaves your machine.",
                actionTitle: "Allow Calendar Access",
                action: service.requestAccess
            )
        case .loading:
            LoadingMessage(title: "Loading events")
        case .denied:
            WidgetMessage(
                symbol: "calendar.badge.exclamationmark",
                title: "Calendar access is off",
                detail: "Turn on Zenotch in Privacy & Security, Calendars.",
                actionTitle: "Open Privacy Settings",
                action: service.openPrivacySettings
            )
        case let .failed(message):
            WidgetMessage(symbol: "exclamationmark.triangle", title: "Could not load events", detail: message, actionTitle: "Try Again", action: service.reload)
        case .ready:
            if service.events.isEmpty {
                WidgetMessage(symbol: "checkmark.circle", title: "Nothing else today or tomorrow")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(groups, id: \.title) { group in
                            Text(group.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Style.tertiary)
                                .padding(.top, group.title == groups.first?.title ? 0 : 6)
                            ForEach(group.events) { event in
                                EventRow(event: event) { service.openCalendarApp(at: event.start) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groups: [(title: String, events: [CalendarService.Event])] {
        let calendar = Calendar.current
        let today = service.events.filter { calendar.isDateInToday($0.start) || ($0.start < Date() && $0.end > Date()) }
        let tomorrow = service.events.filter { !today.contains($0) && calendar.isDateInTomorrow($0.start) }
        return [("Today", today), ("Tomorrow", tomorrow)].filter { !$0.1.isEmpty }
    }
}

private struct DateBlock: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                Text(Date.now, format: .dateTime.day())
                    .font(.system(size: 52, weight: .medium).monospacedDigit())
                    .foregroundStyle(Style.primary)
                Text(Date.now, format: .dateTime.month(.wide).year())
                    .font(.system(size: 12))
                    .foregroundStyle(Style.secondary)
            }
            .frame(width: 110, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help("Open Calendar")
    }
}

private struct EventRow: View {
    let event: CalendarService.Event
    let onOpen: () -> Void

    @ViewState private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Circle().fill(Color(nsColor: event.color)).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Style.primary)
                        .lineLimit(1)
                    if let location = event.location, !location.isEmpty {
                        Text(location).font(.system(size: 11)).foregroundStyle(Style.tertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(timeText)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(isNow ? Style.primary : Style.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hovering ? Style.fill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var isNow: Bool { !event.isAllDay && event.start <= Date() && event.end > Date() }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        if isNow { return "Now" }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}
