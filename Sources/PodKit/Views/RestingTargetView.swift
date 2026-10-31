import SwiftUI

/// What the island leaves at the notch while it is hidden.
///
/// It sits over the camera housing and draws nothing, so nobody sees it — but
/// the pointer can rest on it, a click lands, and VoiceOver finds a labelled
/// button instead of nothing at all.
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
