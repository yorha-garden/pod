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

    /// How content enters and leaves. The morph scales it up out of the
    /// housing, the way the island itself grows; the fade carries its own
    /// timing, because under a fade the shape has none to lend it.
    public var transition: AnyTransition {
        switch self {
        case .spring:
            return .scale(scale: 0.6, anchor: .top).combined(with: .opacity)
        case let .fade(duration):
            return .opacity.animation(.easeInOut(duration: duration))
        }
    }
}
