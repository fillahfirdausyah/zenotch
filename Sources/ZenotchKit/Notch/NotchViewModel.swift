import AppKit
import Observation
import os

let log = Logger(subsystem: "com.fillx.zenotch", category: "notch")

/// Per-screen notch state. Geometry is in global AppKit screen coordinates.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var machine: NotchStateMachine
    private(set) var notchRect: CGRect
    private(set) var screenFrame: CGRect
    private(set) var layout: NotchLayout
    let hasHardwareNotch: Bool
    var isDropTargeted = false

    @ObservationIgnored let app: AppModel

    init(notchRect: CGRect, screenFrame: CGRect, hasHardwareNotch: Bool, app: AppModel) {
        self.notchRect = notchRect
        self.screenFrame = screenFrame
        self.hasHardwareNotch = hasHardwareNotch
        self.app = app
        layout = NotchLayout(notchSize: notchRect.size)
        machine = NotchStateMachine(openOnHover: app.settings.openOnHover)
    }

    var state: NotchState { machine.state }

    var activity: LiveActivity? { app.liveActivity }

    var shapeSize: CGSize { layout.shapeSize(state: state, hasActivity: activity != nil) }

    var radii: (top: CGFloat, bottom: CGFloat) { layout.cornerRadii(state: state) }

    /// Rect of the visible shape including its top ears.
    var shapeRect: CGRect {
        let size = shapeSize
        return NotchGeometry.hangingRect(notch: notchRect, size: CGSize(width: size.width + radii.top * 2, height: size.height))
    }

    /// Area that counts as "hovering the notch"; slightly larger when open so it does not flicker at the edge.
    var hoverZone: CGRect {
        let margin: CGFloat = state == .expanded ? 10 : 4
        return shapeRect.insetBy(dx: -margin, dy: -margin)
    }

    /// Generous target for dragging files toward the notch.
    var dropZone: CGRect {
        NotchGeometry.hangingRect(notch: notchRect, size: CGSize(width: notchRect.width + 160, height: notchRect.height + 40))
            .insetBy(dx: 0, dy: -4)
    }

    var panelFrame: CGRect {
        NotchGeometry.panelFrame(notch: notchRect, size: layout.panelSize, screenFrame: screenFrame)
    }

    @discardableResult
    func send(_ event: NotchEvent) -> Bool {
        machine.openOnHover = app.settings.openOnHover
        let before = machine.state
        let after = machine.handle(event)
        if before != after { log.debug("\(String(describing: event), privacy: .public) moved notch \(String(describing: before), privacy: .public) -> \(String(describing: after), privacy: .public)") }
        if after == .expanded && before != .expanded {
            if app.settings.hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            app.notchDidExpand()
        }
        if after != .expanded { isDropTargeted = false }
        return before != after
    }
}
