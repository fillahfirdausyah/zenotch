import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private var app: AppModel!
    private var coordinator: NotchCoordinator!
    private var statusItem: NSStatusItem!

    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        app = AppModel(settings: settings)
        coordinator = NotchCoordinator(app: app)
        SettingsWindowController.shared = SettingsWindowController(app: app) { [weak self] in
            self?.coordinator.rebuild()
        }
        app.startServices()
        coordinator.start()
        installStatusItem()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        app.stopServices()
    }

    /// Reopening from Finder or Spotlight while running shows Settings, since there is no main window.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared?.show()
        return false
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarImage()
        let menu = NSMenu()
        menu.addItem(item("Open Notch", #selector(openNotch), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Zenotch", #selector(quit), key: "q"))
        statusItem.menu = menu
        #if DEBUG
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.fillx.zenotch.debug"), object: nil, queue: .main) { [weak self] note in
            let parts = (note.object as? String ?? "").split(separator: " ").map(String.init)
            guard parts.first == "statusicon" else { return }
            MainActor.assumeIsolated { self?.saveStatusIcon(to: URL(fileURLWithPath: parts.dropFirst().first ?? "/tmp/zenotch-status.png")) }
        }
        #endif
    }

    /// Falls back to a system symbol when running outside the app bundle, such as `swift run`.
    static func menuBarImage() -> NSImage? {
        guard let image = NSImage(named: "ZenotchMenuBarTemplate") else {
            return NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Zenotch")
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = "Zenotch"
        return image
    }

    private func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    #if DEBUG
    private func saveStatusIcon(to url: URL) {
        guard let button = statusItem.button, let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return }
        button.cacheDisplay(in: button.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        log.notice("status icon template=\(button.image?.isTemplate ?? false, privacy: .public) size=\(String(describing: button.image?.size), privacy: .public)")
    }
    #endif

    @objc private func openNotch() {
        if coordinator.hasVisibleNotch {
            coordinator.expand()
        } else {
            let alert = NSAlert()
            alert.messageText = "No notch on this display"
            alert.informativeText = "Turn on \"Show a notch on displays without one\" in Settings to use Zenotch here."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn { openSettings() }
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
