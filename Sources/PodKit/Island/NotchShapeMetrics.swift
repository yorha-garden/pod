import CoreGraphics

/// The island's corner radii in each state.
///
/// The island is the camera housing grown outward, so its top edge is square
/// and flush with the display edge, its bottom corners are rounded, and at the
/// top it flares out into two small concave "ears" — the curve the bezel makes
/// into the housing — so the join between island and display has no seam.
public struct NotchShapeMetrics: Equatable, Sendable {
    /// Radius of the concave ears at the top. They are drawn outside the
    /// island's frame, one on each side.
    public var topCornerRadius: CGFloat
    /// Radius of the continuous rounded corners at the bottom.
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    /// The largest ear the shape will draw, however tall the island.
    public static let maximumTopCornerRadius: CGFloat = 24

    /// At rest and collapsed: the housing's own corners, measured off a 14"
    /// MacBook Pro — a third of the housing's height at the bottom, and a few
    /// points of flare at the top.
    public static let collapsed = NotchShapeMetrics(topCornerRadius: 3.5, bottomCornerRadius: 12.5)

    /// Lifted under a resting pointer: the same bottom corners, with the ears
    /// opening out as the island pulls away from the housing.
    public static let lifted = NotchShapeMetrics(topCornerRadius: 7.5, bottomCornerRadius: 12.5)

    /// Open: softer corners in proportion to the larger surface.
    public static let expanded = NotchShapeMetrics(topCornerRadius: 17.5, bottomCornerRadius: 36)

    public static func metrics(for state: IslandState, lifted: Bool = false) -> NotchShapeMetrics {
        if state.isExpanded {
            return .expanded
        }
        return lifted ? .lifted : .collapsed
    }

    /// The radii the shape actually draws in a rect, clamped the way the
    /// path needs: the bottom corners to half the width and the full height,
    /// the ears to what is left above the bottom corners and to the maximum.
    public func clamped(to size: CGSize) -> NotchShapeMetrics {
        let bottom = max(0, min(bottomCornerRadius, size.width / 2, size.height))
        let top = min(topCornerRadius, size.height - bottom, Self.maximumTopCornerRadius)

        return NotchShapeMetrics(topCornerRadius: max(0, top), bottomCornerRadius: bottom)
    }
}
