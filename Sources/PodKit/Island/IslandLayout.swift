import CoreGraphics
import Foundation

/// The display the island is on, shared with the views, and the size SwiftUI
/// last laid the island out at, shared back with the app layer.
///
/// SwiftUI owns the island's size — it follows the content, so larger text
/// grows it — and the app layer owns the windows, so this is where the two
/// meet: the views read the housing from here to grow out of it, and report
/// the island's size so the canvas can be kept large enough and the pointer
/// tracked over the island rather than the whole canvas.
@MainActor
public final class IslandLayout: ObservableObject {
    @Published public var geometry: NotchGeometry
    /// The island's laid-out size — the destination of any morph in flight,
    /// not a frame partway through it.
    @Published public var islandSize: CGSize = .zero

    /// What the collapsed content measures, and how tall the open content is
    /// at the open width, measured unseen ahead of time — so a state's size is
    /// known before the island springs to it.
    @Published public var collapsedContentSize: CGSize = .zero
    @Published public var expandedContentHeight: CGFloat = 0

    public init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    /// The island's frame on screen, as last laid out.
    public var islandFrame: CGRect {
        geometry.islandFrame(forSize: islandSize)
    }
}

extension NotchGeometry {
    /// Where an island of a given laid-out size sits on screen: centred on the
    /// display, hanging from its top edge — the same place the canvas pins it.
    public func islandFrame(forSize size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .null }

        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
