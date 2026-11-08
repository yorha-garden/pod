import SwiftUI

/// A plain button that reports when it is held down.
///
/// The island dips under a held click and opens on release — the button's
/// action already fires on release, so all the style adds is the report of
/// the press in between. The label is drawn as is, with no highlight of its
/// own: the island's dip is the feedback.
struct IslandPressButtonStyle: ButtonStyle {
    let onPressChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressChange(pressed)
            }
            .onDisappear {
                // A press interrupted by the island changing state never sees
                // its release.
                onPressChange(false)
            }
    }
}
