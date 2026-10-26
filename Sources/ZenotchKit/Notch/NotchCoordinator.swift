import AppKit

/// Owns one notch window per eligible screen and routes mouse events to them.
@MainActor
final class NotchCoordinator {
    private let app: AppModel
    private var controllers: [NotchWindowController] = []
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var dragHasFiles = false

    init(app: AppModel) {
        self.app = app
    }

    func start() {
        rebuild()
        installMonitors()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        })
        #if DEBUG
        // Lets scripts/drive.sh exercise the notch without real mouse input.
        observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.fillx.zenotch.debug"), object: nil, queue: .main) { [weak self] note in
            let command = note.object as? String ?? ""
            MainActor.assumeIsolated { self?.debugCommand(command) }
        })
        #endif
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        })
    }

    func rebuild() {
        controllers.forEach { $0.close() }
        controllers = NSScreen.screens
            .filter { $0.hasNotch || app.settings.showOnExternalDisplays }
            .map { NotchWindowController(screen: $0, app: app) }
    }

    /// Opens the notch on the screen with the cursor, falling back to the first notch.
    func expand() {
        let mouse = NSEvent.mouseLocation
        let target = controllers.first { $0.model.screenFrame.contains(mouse) } ?? controllers.first
        target?.expandFromMenu()
    }

    func collapseAll() {
        controllers.forEach { $0.collapse() }
    }

    #if DEBUG
    private func debugCommand(_ command: String) {
        let parts = command.split(separator: " ").map(String.init)
        switch parts.first {
        case "expand": expand()
        case "collapse": collapseAll()
        case "media": app.nowPlaying.send(parts.dropFirst().first ?? "toggle")
        case "timer": app.timer.start(TimeInterval(parts.dropFirst().first.flatMap(Int.init) ?? 3))
        case "snapshot": controllers.first?.snapshot(to: URL(fileURLWithPath: parts.dropFirst().first ?? "/tmp/zenotch.png"))
        case "tab": if let tab = parts.dropFirst().first.flatMap(Widget.init(rawValue:)) { app.selectTab(tab); expand() }
        case "statusicon": break
        default: log.error("Unknown debug command \(command)")
        }
        for controller in controllers {
            log.notice("debug state=\(String(describing: controller.model.state), privacy: .public) shape=\(String(describing: controller.model.shapeRect), privacy: .public) tab=\(String(describing: self.app.visibleTab), privacy: .public)")
        }
    }
    #endif

    var hasVisibleNotch: Bool { !controllers.isEmpty }

    private func installMonitors() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        // Global monitors see events going to other apps; local ones see events sent to our panel.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleMove(event) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleMove(event) }
            return event
        }) { monitors.append(local) }
        if let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleClickOutside() }
        }) { monitors.append(clicks) }
        if let ups = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.dragHasFiles = false }
        }) { monitors.append(ups) }
    }

    private func handleMove(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        let dragging = event.type == .leftMouseDragged
        if dragging { refreshDragPasteboard() }
        for controller in controllers {
            controller.mouseMoved(to: point, isDragging: dragging, dragHasFiles: dragging && dragHasFiles)
        }
    }

    private func handleClickOutside() {
        let point = NSEvent.mouseLocation
        dragChangeCount = NSPasteboard(name: .drag).changeCount
        dragHasFiles = false
        controllers.forEach { $0.mouseDown(at: point) }
    }

    /// A new drag session writes to the drag pasteboard, bumping its change count.
    private func refreshDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragChangeCount else { return }
        dragChangeCount = pasteboard.changeCount
        dragHasFiles = pasteboard.types?.contains(.fileURL) == true
    }
}
