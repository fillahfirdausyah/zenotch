import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @Bindable var model: NotchViewModel

    var body: some View {
        let radii = model.radii
        let size = model.shapeSize
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)
        let frameWidth = size.width + radii.top * 2

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                shape.fill(Color.black)
                content
                    .padding(.horizontal, radii.top)
                    .frame(width: frameWidth, height: size.height, alignment: .top)
                    .clipShape(shape)
                if model.isDropTargeted {
                    shape
                        .stroke(Style.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .padding(.horizontal, radii.top - 1)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: frameWidth, height: size.height)
            // Elevation only when open, where the panel overlaps app windows.
            .shadow(color: .black.opacity(model.state == .expanded ? 0.5 : 0), radius: 14, y: 6)
            .contentShape(shape)
            .onTapGesture {
                if model.state != .expanded { model.send(.clicked) }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted, perform: handleDrop)
            .offset(x: model.notchRect.midX - model.panelFrame.midX)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Style.spring, value: model.state)
        .animation(Style.spring, value: model.activity)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .expanded:
            ExpandedNotchView(model: model)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.08)),
                    removal: .opacity.animation(.easeIn(duration: 0.08))
                ))
        case .collapsed, .peek:
            if let activity = model.activity {
                ActivityWingsView(
                    activity: activity,
                    app: model.app,
                    notchWidth: model.notchRect.width,
                    wingWidth: model.layout.wingWidth,
                    height: model.shapeSize.height
                )
                .transition(.opacity)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        let app = model.app
        Task { @MainActor in
            var urls: [URL] = []
            for provider in fileProviders {
                if let url = await Self.loadURL(provider) { urls.append(url) }
            }
            app.shelf.add(urls: urls)
            app.selectTab(.shelf)
        }
        return true
    }

    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
