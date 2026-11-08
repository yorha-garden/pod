import SwiftUI

/// The island's surface: flat black, the housing's own colour.
///
/// Anything lighter or translucent would show a seam where the island meets
/// the housing, and black under light text also means the text's contrast
/// never depends on the wallpaper behind it. Increase Contrast adds a border,
/// so the island's edge is unmistakable against a dark desktop.
struct IslandBackground: View {
    let style: IslandStyle
    let shape: NotchShape

    var body: some View {
        shape
            .fill(Color.black)
            .overlay {
                if style.borderWidth > 0 {
                    shape.stroke(Color.white, lineWidth: style.borderWidth * 2)
                        // Stroked at twice the width and clipped back to the
                        // shape: an inside border, so the island's footprint
                        // — and the pointer region tracked from it — does not
                        // change when the setting does.
                        .clipShape(shape)
                }
            }
    }
}
