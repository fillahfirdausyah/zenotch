import SwiftUI

struct ClipboardView: View {
    let service: ClipboardService
    let settings: SettingsStore
    let onEnable: () -> Void

    var body: some View {
        if !settings.recordClipboard {
            WidgetMessage(
                symbol: "pause.circle",
                title: "Clipboard history is paused",
                detail: "Text you copy is only kept in memory and is cleared when Zenotch quits.",
                actionTitle: "Resume Recording",
                action: {
                    settings.recordClipboard = true
                    onEnable()
                }
            )
        } else if service.history.entries.isEmpty {
            WidgetMessage(
                symbol: "doc.on.clipboard",
                title: "Nothing copied yet",
                detail: "Copied text appears here. Passwords from password managers are skipped."
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Click to copy again")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Style.secondary)
                    Spacer()
                    PillButton(title: "Clear History", action: service.clear)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(service.history.entries) { entry in
                            ClipboardRow(entry: entry, service: service)
                        }
                    }
                }
            }
        }
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let service: ClipboardService

    @ViewState private var hovering = false
    @ViewState private var copied = false

    var body: some View {
        Button {
            service.copy(entry)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
        } label: {
            HStack(spacing: 10) {
                Text(entry.preview)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Style.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if copied {
                    Text("Copied").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                } else {
                    Text(entry.copiedAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                        .font(.system(size: 11))
                        .foregroundStyle(Style.tertiary)
                }
                if hovering {
                    Button { service.remove(entry) } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Style.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hovering ? Style.fill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(entry.text.count > 300 ? String(entry.text.prefix(300)) + "…" : entry.text)
    }
}
