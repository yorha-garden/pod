import SwiftUI

/// What the island leaves at the notch while it is hidden.
///
/// It is the camera housing exactly, filled black where the display has no
/// pixels, so nobody sees it — but the pointer can rest on it, a click lands,
/// and VoiceOver finds a labelled button instead of nothing at all. The black
/// fill is also what makes it hittable: the panel only takes the pointer where
/// something is drawn.
struct RestingTargetView: View {
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Clear content has no hit area of its own; this gives it one.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show Pod")
        .accessibilityHint("Control Option Space also works.")
    }
}
