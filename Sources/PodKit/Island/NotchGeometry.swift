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

    // MARK: The island grows out of the housing

    /// How much wider the open island is than the housing it grows out of,
    /// and the narrowest it gets on a small housing.
    public static let expandedExtraWidth: CGFloat = 160
    public static let expandedMinimumWidth: CGFloat = 345
    /// How far the open island hangs below the housing, and the shortest it
    /// gets.
    public static let expandedExtraHeight: CGFloat = 142
    public static let expandedMinimumHeight: CGFloat = 175

    /// The smallest the island is drawn in a state, before its content asks
    /// for more.
    ///
    /// Hidden, it is the housing exactly: a black shape where the display has
    /// no pixels, so nothing shows, but something is there to rest the pointer
    /// on. Collapsed, it is at least as tall as the housing and never shorter
    /// than the hit-target floor. Open, it is the housing grown outward.
    public func minimumIslandSize(for state: IslandState) -> CGSize {
        switch state {
        case .hidden:
            return housingSize
        case .collapsed:
            return CGSize(
                width: housingSize.width,
                height: max(housingSize.height, IslandStyle.hitTargetFloor)
            )
        case .expanded:
            return CGSize(
                width: max(housingSize.width + Self.expandedExtraWidth, Self.expandedMinimumWidth),
                height: max(housingSize.height + Self.expandedExtraHeight, Self.expandedMinimumHeight)
            )
        }
    }

    /// The size the island is drawn at in a state: the size its morph springs
    /// toward.
    ///
    /// Given explicitly rather than left to the content, so the island's frame
    /// itself interpolates between states instead of jumping to whatever the
    /// incoming content measures. At rest it is the housing; collapsed it is
    /// what the content measures, at least the minimum; open it is the
    /// housing grown to a fixed width, taller only when larger text needs it.
    ///
    /// - Parameters:
    ///   - collapsedContent: the collapsed content's own size.
    ///   - expandedContentHeight: the open content's height at the open width.
    public func islandSize(
        for state: IslandState,
        collapsedContent: CGSize,
        expandedContentHeight: CGFloat
    ) -> CGSize {
        let minimum = minimumIslandSize(for: state)

        switch state {
        case .hidden:
            return minimum
        case .collapsed:
            return CGSize(
                width: min(max(minimum.width, collapsedContent.width), screenFrame.width),
                height: min(max(minimum.height, collapsedContent.height), screenFrame.height)
            )
        case .expanded:
            return CGSize(
                width: min(minimum.width, screenFrame.width),
                height: min(max(minimum.height, expandedContentHeight), screenFrame.height)
            )
        }
    }

    // MARK: The canvas the island morphs inside

    /// The canvas is never smaller than this, so ordinary growth never has to
    /// touch the windows.
    public static let minimumCanvasSize = CGSize(width: 640, height: 320)

    /// Room around the island for its shadow, its top ears and the hover lift.
    public static let canvasMargin: CGFloat = 40

    /// The fixed frame both island panels share: centred on the display,
    /// hanging from its top edge, large enough for the island plus its margin
    /// and clamped to the display.
    ///
    /// The width keeps the display's parity, so the canvas — and the island
    /// centred in it — lands on the same centre line as the housing rather
    /// than half a point off it.
    public func canvasFrame(fitting island: CGSize) -> CGRect {
        let wanted = max(Self.minimumCanvasSize.width, island.width + 2 * Self.canvasMargin)
        let side = max(0, ((screenFrame.width - wanted) / 2).rounded(.down))
        let width = screenFrame.width - 2 * side
        let height = min(
            screenFrame.height,
            max(Self.minimumCanvasSize.height, island.height + Self.canvasMargin).rounded(.up)
        )

        return CGRect(
            x: screenFrame.minX + side,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Whether a canvas still has room for an island of this size.
    public func canvas(_ canvas: CGRect, fits island: CGSize) -> Bool {
        let needed = canvasFrame(fitting: island)
        return canvas.width >= needed.width && canvas.height >= needed.height
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
