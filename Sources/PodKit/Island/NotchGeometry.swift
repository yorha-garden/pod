import CoreGraphics
import Foundation

/// Where the island sits on a display.
///
/// Pure geometry, deliberately free of AppKit, so placement can be tested
/// without a screen — including the cases that are awkward to reproduce by
/// hand: an external display with no camera housing, a housing wider than the
/// island, and content too large for the display it is on.
public struct NotchGeometry: Equatable, Sendable {
    /// The display's frame in AppKit coordinates, origin bottom-left.
    public let screenFrame: CGRect
    /// The camera housing's size. Zero on displays without one.
    public let housingSize: CGSize

    public init(screenFrame: CGRect, housingSize: CGSize = .zero) {
        self.screenFrame = screenFrame
        self.housingSize = housingSize
    }

    public var hasHousing: Bool {
        housingSize.width > 0 && housingSize.height > 0
    }

    /// The housing itself, centred on the display's top edge.
    public var housingRect: CGRect {
        guard hasHousing else { return .null }

        return CGRect(
            x: screenFrame.midX - housingSize.width / 2,
            y: screenFrame.maxY - housingSize.height,
            width: housingSize.width,
            height: housingSize.height
        )
    }

    /// The island's frame for a given content size.
    ///
    /// Derived from the content instead of a fixed constant, so the island
    /// grows when the user's text size does rather than clipping it — and
    /// clamped to the display, so it can never grow off-screen.
    public func frame(forContentOfSize content: CGSize, minimumWidth: CGFloat = 0) -> CGRect {
        let floorWidth = max(minimumWidth, housingSize.width)
        let width = min(max(content.width, floorWidth), screenFrame.width)
        let height = min(
            max(content.height, IslandStyle.hitTargetFloor),
            screenFrame.height
        )

        return CGRect(
            x: (screenFrame.midX - width / 2).rounded(),
            y: (screenFrame.maxY - height).rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }

    /// The part of `frame` hidden behind the physical camera housing.
    ///
    /// Readable content must never be laid out inside this rect. Returns
    /// `.null` on displays without a housing.
    public func occlusion(in frame: CGRect) -> CGRect {
        guard hasHousing else { return .null }

        let overlap = frame.intersection(housingRect)
        return overlap.isEmpty ? .null : overlap
    }

    /// Top inset that clears the housing for a given frame, in points.
    ///
    /// Zero where there is nothing to clear, so the same layout code works on
    /// an external display.
    public func topInsetClearingHousing(in frame: CGRect) -> CGFloat {
        let overlap = occlusion(in: frame)
        return overlap.isNull ? 0 : overlap.height
    }
}
