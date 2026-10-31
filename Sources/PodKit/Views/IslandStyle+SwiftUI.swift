import SwiftUI

extension MotionTreatment {
    /// The animation this treatment implies.
    public var animation: Animation {
        switch self {
        case let .spring(response, dampingFraction):
            return .spring(response: response, dampingFraction: dampingFraction)
        case let .crossFade(duration):
            return .easeInOut(duration: duration)
        }
    }

    /// Reduce Motion gets a fade in place. Everyone else gets the scale, which
    /// is the part that reads as the island growing out of the notch.
    public var transition: AnyTransition {
        allowsGeometryMorph
            ? .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
            : .opacity
    }
}
