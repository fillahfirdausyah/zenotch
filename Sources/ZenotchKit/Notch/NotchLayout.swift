import CoreGraphics

/// Shape sizes per state. The collapsed shape matches the hardware notch so it is invisible
/// until a live activity adds wings on either side.
public struct NotchLayout: Equatable, Sendable {
    public var notchSize: CGSize
    public var wingWidth: CGFloat = 72
    public var peekGrowth = CGSize(width: 36, height: 6)
    public var expandedSize = CGSize(width: 640, height: 236)
    public var shadowPadding: CGFloat = 24

    public init(notchSize: CGSize) {
        self.notchSize = notchSize
    }

    public func shapeSize(state: NotchState, hasActivity: Bool) -> CGSize {
        let wings = hasActivity ? wingWidth * 2 : 0
        switch state {
        case .collapsed:
            return CGSize(width: notchSize.width + wings, height: notchSize.height)
        case .peek:
            return CGSize(
                width: notchSize.width + wings + peekGrowth.width,
                height: notchSize.height + peekGrowth.height
            )
        case .expanded:
            return CGSize(
                width: max(expandedSize.width, notchSize.width + 200),
                height: max(expandedSize.height, notchSize.height + 120)
            )
        }
    }

    public func cornerRadii(state: NotchState) -> (top: CGFloat, bottom: CGFloat) {
        switch state {
        case .collapsed: (6, 10)
        case .peek: (8, 14)
        case .expanded: (14, 28)
        }
    }

    /// The panel never resizes, so it is sized for the largest shape plus room for its shadow.
    public var panelSize: CGSize {
        let expanded = shapeSize(state: .expanded, hasActivity: false)
        let top = cornerRadii(state: .expanded).top
        return CGSize(width: expanded.width + top * 2 + shadowPadding * 2, height: expanded.height + shadowPadding)
    }
}
