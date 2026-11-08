import AppKit
import SwiftUI

/// Hosts the island's SwiftUI inside a panel, with the safe area turned off.
///
/// At the top of a display with a camera housing, AppKit reports the housing's
/// band as an unsafe area and SwiftUI would lay content out below it. The
/// island is meant to occupy that band — it is the housing grown — so the
/// insets are zeroed here, and the root view ignores the safe area as well.
///
/// The view never sizes its window: the panel is a fixed canvas, set by the
/// app layer, and the island morphs inside it.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = []
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }
}
