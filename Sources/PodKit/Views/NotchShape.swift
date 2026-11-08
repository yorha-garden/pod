import SwiftUI

/// The island's outline: the camera housing, grown.
///
/// A square top flush with the display's edge, continuous rounded corners at
/// the bottom, and at the top two concave ears that flare outward past the
/// frame — the curve where the bezel meets the housing — so the island reads
/// as part of the housing rather than a pill floating under it. Leave
/// `topCornerRadius` of room either side for the ears.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(_ metrics: NotchShapeMetrics) {
        topCornerRadius = metrics.topCornerRadius
        bottomCornerRadius = metrics.bottomCornerRadius
    }

    /// Both radii animate, so the corners soften as the island opens on the
    /// same spring as its size.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let radii = NotchShapeMetrics(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        ).clamped(to: rect.size)

        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radii.bottomCornerRadius,
                bottomTrailing: radii.bottomCornerRadius,
                topTrailing: 0
            ),
            style: .continuous
        )

        let ear = radii.topCornerRadius
        guard ear > 0 else { return path }

        // Each ear is the corner of a square beside the island that a rounded
        // square of the same size leaves uncovered: concave toward the island.
        let left = CGRect(x: rect.minX - 2 * ear, y: rect.minY, width: 2 * ear, height: 2 * ear)
        path.addPath(Path(left).subtracting(Path(
            roundedRect: left,
            cornerRadii: RectangleCornerRadii(topTrailing: ear),
            style: .continuous
        )))

        let right = CGRect(x: rect.maxX, y: rect.minY, width: 2 * ear, height: 2 * ear)
        path.addPath(Path(right).subtracting(Path(
            roundedRect: right,
            cornerRadii: RectangleCornerRadii(topLeading: ear),
            style: .continuous
        )))

        return path
    }
}
