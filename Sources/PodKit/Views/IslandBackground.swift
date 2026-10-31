import SwiftUI

/// The island's surface, resolved from the accessibility style.
struct IslandBackground: View {
    let style: IslandStyle
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(fill)
            .overlay {
                if style.borderWidth > 0 {
                    shape.strokeBorder(.primary, lineWidth: style.borderWidth)
                }
            }
    }

    private var fill: AnyShapeStyle {
        switch style.background {
        case .material:
            return AnyShapeStyle(.regularMaterial)
        case .opaque:
            // Flat, so the text's contrast never depends on the wallpaper
            // that happens to be behind the island.
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }
}
