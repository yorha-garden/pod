import CoreGraphics
import Foundation

/// How the island moves between states.
public enum MotionTreatment: Equatable, Sendable {
    case spring(response: Double, dampingFraction: Double)
    case crossFade(duration: Double)

    /// Whether the island may visibly travel and resize between states.
    ///
    /// The springy morph is the signature of this kind of UI and also the
    /// effect most likely to provoke vestibular symptoms, so Reduce Motion
    /// replaces it with a fade in place rather than merely shortening it.
    public var allowsGeometryMorph: Bool {
        switch self {
        case .spring:
            return true
        case .crossFade:
            return false
        }
    }

    public var duration: Double {
        switch self {
        case let .spring(response, _):
            return response
        case let .crossFade(duration):
            return duration
        }
    }

    /// Whether moving the panel to a new frame should animate.
    ///
    /// Only between two on-screen states, and only where the morph is allowed.
    /// Appearing from hidden has no previous frame worth animating from — on
    /// the first presentation the panel's last frame is wherever it was
    /// constructed — so the island is placed first and shown where it belongs.
    public func animatesFrameChange(panelWasOnScreen: Bool) -> Bool {
        panelWasOnScreen && allowsGeometryMorph
    }
}

/// How the island's surface is filled.
public enum BackgroundTreatment: Equatable, Sendable {
    /// Translucent system material over the desktop.
    case material
    /// Flat fill, so text contrast never depends on the wallpaper behind it.
    case opaque
}

/// The resolved visual treatment for one set of accessibility preferences.
public struct IslandStyle: Equatable, Sendable {
    public var motion: MotionTreatment
    public var background: BackgroundTreatment
    public var borderWidth: CGFloat
    /// Views must pair every colour-coded state with a glyph and a label.
    public var requiresNonColorStateCue: Bool
    /// Hit target floor in points, whatever the drawn size is.
    public var minimumHitTarget: CGFloat

    public init(
        motion: MotionTreatment,
        background: BackgroundTreatment,
        borderWidth: CGFloat,
        requiresNonColorStateCue: Bool,
        minimumHitTarget: CGFloat
    ) {
        self.motion = motion
        self.background = background
        self.borderWidth = borderWidth
        self.requiresNonColorStateCue = requiresNonColorStateCue
        self.minimumHitTarget = minimumHitTarget
    }

    /// Apple's hit target floor for pointer and touch alike.
    public static let hitTargetFloor: CGFloat = 44

    public static func resolve(for preferences: AccessibilityPreferences) -> IslandStyle {
        IslandStyle(
            motion: preferences.reduceMotion
                ? .crossFade(duration: 0.12)
                : .spring(response: 0.34, dampingFraction: 0.78),
            // Increase Contrast implies an opaque fill too: a blur puts the
            // wallpaper's contrast in charge of the text's legibility.
            background: preferences.reduceTransparency || preferences.increaseContrast
                ? .opaque
                : .material,
            borderWidth: preferences.increaseContrast ? 2 : 0,
            // Always on. Colour is never the only cue for a state, whether or
            // not the user asked — the setting just makes the lapse visible.
            requiresNonColorStateCue: true,
            minimumHitTarget: hitTargetFloor
        )
    }
}
