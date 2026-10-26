import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    let model: NotchViewModel
    let screenID: CGDirectDisplayID
    private let panel: NotchPanel

    private var enterWork: DispatchWorkItem?
    private var exitWork: DispatchWorkItem?
    /// Opened from the menu while the cursor was elsewhere: stay open until the cursor arrives.
    private var pinnedUntilHover = false

    init(screen: NSScreen, app: AppModel) {
        let frame = screen.frame
        let notch = NotchGeometry.notchRect(
            screenFrame: frame,
            topLeftArea: screen.auxiliaryTopLeftArea,
            topRightArea: screen.auxiliaryTopRightArea
        )
        let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
        model = NotchViewModel(
            notchRect: notch ?? NotchGeometry.fallbackRect(screenFrame: frame, menuBarHeight: menuBarHeight),
            screenFrame: frame,
            hasHardwareNotch: notch != nil,
            app: app
        )
        screenID = screen.displayID
        panel = NotchPanel(frame: model.panelFrame)
        let host = NotchHostingView(rootView: NotchRootView(model: model))
        host.frame = CGRect(origin: .zero, size: model.panelFrame.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(model.panelFrame, display: false)
        panel.orderFrontRegardless()
    }

    func close() {
        enterWork?.cancel()
        exitWork?.cancel()
        panel.orderOut(nil)
        panel.close()
    }

    /// Handles every mouse move, whether it arrived through the global or local monitor.
    func mouseMoved(to point: CGPoint, isDragging: Bool, dragHasFiles: Bool) {
        if isDragging, dragHasFiles, model.state != .expanded, model.dropZone.contains(point) {
            cancelTimers()
            model.app.selectTab(.shelf)
            update(.dragEntered)
            return
        }

        let inside = model.hoverZone.contains(point)
        switch model.state {
        case .collapsed:
            exitWork?.cancel()
            if inside, !isDragging { scheduleEnter() } else { enterWork?.cancel() }
        case .peek, .expanded:
            enterWork?.cancel()
            // Keep the notch open while a drag that started inside it (like a shelf item) is in flight.
            if inside { pinnedUntilHover = false }
            if inside || pinnedUntilHover || (isDragging && !dragHasFiles && model.state == .expanded) {
                exitWork?.cancel()
            } else {
                scheduleExit()
            }
        }
        updateMouseThrough(at: point)
    }

    func mouseDown(at point: CGPoint) {
        guard model.state != .collapsed, !model.hoverZone.contains(point) else { return }
        cancelTimers()
        pinnedUntilHover = false
        update(.clickedOutside)
    }

    func expandFromMenu() {
        cancelTimers()
        pinnedUntilHover = !model.hoverZone.contains(NSEvent.mouseLocation)
        update(.clicked)
        panel.ignoresMouseEvents = false
    }

    func collapse() {
        cancelTimers()
        pinnedUntilHover = false
        update(.dismissed)
    }

    /// Clicks pass through to the menu bar except where the shape is visible and open.
    func updateMouseThrough(at point: CGPoint) {
        let interactive = model.state != .collapsed && model.hoverZone.contains(point)
        if panel.ignoresMouseEvents == interactive {
            panel.ignoresMouseEvents = !interactive
        }
    }

    #if DEBUG
    func snapshot(to url: URL) {
        guard let view = panel.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
    #endif

    private func update(_ event: NotchEvent) {
        model.send(event)
        updateMouseThrough(at: NSEvent.mouseLocation)
    }

    private func scheduleEnter() {
        guard enterWork == nil || enterWork!.isCancelled else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.enterWork = nil
            guard self.model.hoverZone.contains(NSEvent.mouseLocation) else { return }
            self.update(.hoverEntered)
        }
        enterWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.02, model.app.settings.hoverDelay), execute: work)
    }

    private func scheduleExit() {
        guard exitWork == nil || exitWork!.isCancelled else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.exitWork = nil
            guard !self.pinnedUntilHover, !self.model.hoverZone.contains(NSEvent.mouseLocation), NSEvent.pressedMouseButtons == 0 else { return }
            self.update(.hoverExited)
        }
        exitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (model.state == .expanded ? 0.45 : 0.15), execute: work)
    }

    private func cancelTimers() {
        enterWork?.cancel()
        enterWork = nil
        exitWork?.cancel()
        exitWork = nil
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var hasNotch: Bool { auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil && safeAreaInsets.top > 0 }
}
