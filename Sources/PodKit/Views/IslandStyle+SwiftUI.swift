import SwiftUI

extension SpringCurve {
    /// The SwiftUI animation for this spring.
    public var animation: Animation {
        switch self {
        case let .bounce(duration, bounce):
            return .spring(Spring(duration: duration, bounce: bounce))
        case let .response(response, dampingFraction):
            return .spring(response: response, dampingFraction: dampingFraction)
        }
    }
}

extension IslandMotion {
    /// The animation the island's shape moves on, or none: under a fade the
    /// shape takes its new size at once and only the content changes, so
    /// nothing travels or scales.
    public var shapeAnimation: Animation? {
        switch self {
        case let .spring(curve):
            return curve.animation
        case .fade:
            return nil
        }
    }

    /// How content enters and leaves. The morph grows it out of the island's
    /// centre, coming into focus as it fades in; the fade carries its own
    /// timing, because under a fade the shape has none to lend it.
    public var transition: AnyTransition {
        switch self {
        case .spring:
            let entrance = contentEntrance
            return .modifier(
                active: ContentEntranceEffect(scale: entrance.scale, blur: entrance.blur, opacity: 0),
                identity: ContentEntranceEffect(scale: 1, blur: 0, opacity: 1)
            )
        case let .fade(duration):
            return .opacity.animation(.easeInOut(duration: duration))
        }
    }
}

/// Scale about the centre, blur and opacity, applied together so one
/// transition can carry all three.
struct ContentEntranceEffect: ViewModifier {
    let scale: Double
    let blur: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .center)
            .blur(radius: blur)
            .opacity(opacity)
    }
}
