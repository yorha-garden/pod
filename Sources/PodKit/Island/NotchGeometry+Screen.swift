import AppKit

extension NotchGeometry {
    /// Reads the housing dimensions macOS reports for a display.
    ///
    /// `safeAreaInsets.top` carries the housing height, and the width is
    /// whatever the two auxiliary top areas leave between them. A display
    /// without a housing reports no auxiliary areas and resolves to a zero
    /// size, which the geometry treats as "no housing to work around".
    public init(screen: NSScreen) {
        let height = screen.safeAreaInsets.top
        var width: CGFloat = 0

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            width = max(0, screen.frame.width - left.width - right.width)
        }

        let housing = height > 0 && width > 0
            ? CGSize(width: width, height: height)
            : .zero

        self.init(screenFrame: screen.frame, housingSize: housing)
    }
}
