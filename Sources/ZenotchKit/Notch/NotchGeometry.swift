import CoreGraphics

/// Geometry in AppKit screen coordinates (origin bottom-left, y up).
public enum NotchGeometry {
    public static let fallbackNotchWidth: CGFloat = 200
    public static let fallbackNotchHeight: CGFloat = 32

    /// The hardware notch is the gap between the two auxiliary top areas. Only widths are used
    /// because the areas' origins are not consistently screen-relative across displays.
    public static func notchRect(screenFrame: CGRect, topLeftArea: CGRect?, topRightArea: CGRect?) -> CGRect? {
        guard let left = topLeftArea, let right = topRightArea else { return nil }
        let width = screenFrame.width - left.width - right.width
        let height = max(left.height, right.height)
        guard width > 0, height > 0 else { return nil }
        return CGRect(x: screenFrame.minX + left.width, y: screenFrame.maxY - height, width: width, height: height)
    }

    public static func fallbackRect(screenFrame: CGRect, menuBarHeight: CGFloat) -> CGRect {
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackNotchHeight
        return CGRect(
            x: screenFrame.midX - fallbackNotchWidth / 2,
            y: screenFrame.maxY - height,
            width: fallbackNotchWidth,
            height: height
        )
    }

    /// A rect of `size` hanging from the top edge, centered on the notch.
    public static func hangingRect(notch: CGRect, size: CGSize) -> CGRect {
        CGRect(x: notch.midX - size.width / 2, y: notch.maxY - size.height, width: size.width, height: size.height)
    }

    /// Panel frame centered on the notch, shifted horizontally to stay on screen.
    public static func panelFrame(notch: CGRect, size: CGSize, screenFrame: CGRect) -> CGRect {
        var frame = hangingRect(notch: notch, size: size)
        if frame.minX < screenFrame.minX { frame.origin.x = screenFrame.minX }
        if frame.maxX > screenFrame.maxX { frame.origin.x = screenFrame.maxX - size.width }
        return frame
    }

    /// Hover zone for a shape of `size`. The outset also covers the screen's top edge,
    /// where the cursor rests at exactly maxY and CGRect.contains would exclude it.
    public static func hoverZone(notch: CGRect, size: CGSize, margin: CGFloat = 4) -> CGRect {
        hangingRect(notch: notch, size: size).insetBy(dx: -margin, dy: -margin)
    }
}
