import AppKit
import SwiftUI

struct ShelfView: View {
    let store: ShelfStore
    let isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.items.isEmpty {
                WidgetMessage(
                    symbol: isDropTargeted ? "tray.and.arrow.down.fill" : "tray",
                    title: isDropTargeted ? "Drop to keep it here" : "Shelf is empty",
                    detail: "Drag files onto the notch to park them, then drag them out wherever you need them."
                )
            } else {
                HStack {
                    Text(store.items.count == 1 ? "1 item" : "\(store.items.count) items")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Style.secondary)
                    if let error = store.lastError {
                        Text(error).font(.system(size: 11)).foregroundStyle(.orange).lineLimit(1)
                    }
                    Spacer()
                    PillButton(title: "Clear Shelf", action: store.clear)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.items) { item in
                            ShelfTile(item: item, store: store)
                        }
                    }
                }
            }
        }
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let store: ShelfStore

    @ViewState private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: store.icon(for: item))
                .resizable()
                .frame(width: 52, height: 52)
            Text(item.name)
                .font(.system(size: 11))
                .foregroundStyle(Style.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
        }
        .frame(width: 88)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Style.fillHover : Style.fill))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { store.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Style.primary, Color.black.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove from shelf")
                .padding(4)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { store.open(item) }
        .onDrag {
            guard let url = item.resolveURL() else { return NSItemProvider() }
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        }
        .contextMenu {
            Button("Open") { store.open(item) }
            Button("Show in Finder") { store.reveal(item) }
            Divider()
            Button("Remove from Shelf") { store.remove(item) }
        }
        .help("\(item.name). Drag out to use, double-click to open.")
    }
}
