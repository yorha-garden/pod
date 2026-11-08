import CoreGraphics
import Foundation

/// One spring, in either of the two ways SwiftUI parameterises one.
public enum SpringCurve: Equatable, Sendable {
    /// `Spring(duration:bounce:)`: a perceived duration, and a bounce from
    /// -1 (heavily overdamped) through 0 (no overshoot) to 1.
    case bounce(duration: Double, bounce: Double)
    /// `spring(response:dampingFraction:)`. A damping fraction of 1 is
    /// critically damped: the quickest settle with no overshoot.
    case response(Double, dampingFraction: Double)

    /// Roughly how long the motion takes to read as finished.
    public var duration: Double {
        switch self {
        case let .bounce(duration, _):
            return duration
        case let .response(response, _):
            return response
        }
    }

    /// Whether the curve overshoots its target.
    public var overshoots: Bool {
        switch self {
        case let .bounce(_, bounce):
            return bounce > 0
        case let .response(_, dampingFraction):
            return dampingFraction < 1
        }
    }
}

/// The springs the island morphs with.
public struct MorphTiming: Equatable, Sendable {
    /// Growing: out of the housing, or from collapsed to open.
    public var open: SpringCurve
    /// Shrinking back toward the housing. Settles without overshoot, so the
    /// island never bounces past the housing it is returning into.
    public var close: SpringCurve
    /// Changing what is shown without growing or shrinking a step.
    public var settle: SpringCurve
    /// The small lift while the pointer rests on the island.
    public var hover: SpringCurve
    /// The dip under a held click, and the return from it.
    public var press: SpringCurve

    public init(
        open: SpringCurve,
        close: SpringCurve,
        settle: SpringCurve,
        hover: SpringCurve,
        press: SpringCurve
    ) {
        self.open = open
        self.close = close
        self.settle = settle
        self.hover = hover
        self.press = press
    }

    /// The island's timings.
    ///
    /// Opening overshoots by about 8% and is still within a couple of points
    /// of rest at 0.6s, which reads as the island springing out of the
    /// housing rather than sliding. Closing is critically damped — the
    /// quickest settle with no overshoot — so the island never bounces past
    /// the housing it returns into. Holding steps settle a little slower,
    /// with no overshoot either, the hover lift is short and springy, and
    /// the dip under a held click is quick and does not bounce.
    public static let standard = MorphTiming(
        open: .bounce(duration: 0.44, bounce: 0.375),
        close: .response(0.4, dampingFraction: 1),
        settle: .response(0.4875, dampingFraction: 1),
        hover: .bounce(duration: 0.35, bounce: 0.3),
        press: .response(0.3, dampingFraction: 1)
    )
}

/// How much the island grows while the pointer rests on it, in points.
public struct HoverLift: Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    /// Enough to see without looking for it: wider by 14 points and taller by
    /// six, out of a housing a couple of hundred points across.
    public static let standard = HoverLift(width: 14, height: 6)

    /// Held under a click, the lifted island dips back 8 by 5 points — the
    /// press is felt before the release opens it.
    public static let pressed = HoverLift(width: 6, height: 1)

    public static let none = HoverLift(width: 0, height: 0)

    /// How far the island's surface reaches past its frame.
    public static func outset(lifted: Bool, pressed isPressed: Bool) -> HoverLift {
        guard lifted else { return .none }
        return isPressed ? .pressed : .standard
    }
}

/// What one change of state gets.
public enum IslandMotion: Equatable, Sendable {
    /// The shape morphs on a spring: resizes, and the content scales in.
    case spring(SpringCurve)
    /// Nothing travels or resizes visibly; the content fades in place.
    case fade(duration: Double)
}

/// How a state's content comes in and goes out while the island changes.
///
/// Under the morph the content grows out of the island's centre from half
/// size, coming into focus as it fades in, and leaves the same way, so it
/// arrives and departs with the shape rather than sliding across it. Under a
/// fade it only fades.
public struct ContentEntrance: Equatable, Sendable {
    /// The content's scale at the start of its entrance and the end of its exit.
    public var scale: Double
    /// Its blur radius, in points, at those same moments.
    public var blur: Double

    public init(scale: Double, blur: Double) {
        self.scale = scale
        self.blur = blur
    }

    public static let morph = ContentEntrance(scale: 0.5, blur: 4)
    public static let fade = ContentEntrance(scale: 1, blur: 0)
}

extension IslandMotion {
    public var contentEntrance: ContentEntrance {
        switch self {
        case .spring:
            return .morph
        case .fade:
            return .fade
        }
    }
}

/// A change from one state to another, kept so the view can pick the motion
/// for the step it is actually taking.
public struct IslandTransition: Equatable, Sendable {
    public var from: IslandState
    public var to: IslandState

    public init(from: IslandState, to: IslandState) {
        self.from = from
        self.to = to
    }

    public static let none = IslandTransition(from: .hidden, to: .hidden)

    /// Which way the island is going: growing toward open, shrinking toward
    /// the housing, or staying the same size.
    public var direction: Direction {
        let from = Self.rank(of: self.from)
        let to = Self.rank(of: self.to)
        return to > from ? .growing : to < from ? .shrinking : .holding
    }

    public enum Direction: Equatable, Sendable {
        case growing
        case shrinking
        case holding
    }

    private static func rank(of state: IslandState) -> Int {
        switch state {
        case .hidden: 0
        case .collapsed: 1
        case .expanded: 2
        }
    }
}

/// How the island moves between states.
public enum MotionTreatment: Equatable, Sendable {
    case morph(MorphTiming)
    case crossFade(duration: Double)

    /// Whether the island may visibly travel and resize between states.
    ///
    /// The springy morph is the signature of this kind of UI and also the
    /// effect most likely to provoke vestibular symptoms, so Reduce Motion
    /// replaces it with a fade in place rather than merely shortening it.
    public var allowsGeometryMorph: Bool {
        switch self {
        case .morph:
            return true
        case .crossFade:
            return false
        }
    }

    /// The motion for one step between states.
    public func motion(for transition: IslandTransition) -> IslandMotion {
        switch self {
        case let .morph(timing):
            switch transition.direction {
            case .growing:
                return .spring(timing.open)
            case .shrinking:
                return .spring(timing.close)
            case .holding:
                return .spring(timing.settle)
            }
        case let .crossFade(duration):
            return .fade(duration: duration)
        }
    }

    /// The dip under a held click, or nothing at all: under Reduce Motion the
    /// island does not move until it opens.
    public var pressDip: SpringCurve? {
        switch self {
        case let .morph(timing):
            return timing.press
        case .crossFade:
            return nil
        }
    }

    /// The lift while the pointer rests on the island, or nothing at all.
    /// Under Reduce Motion the island does not move to acknowledge the
    /// pointer; the expansion that follows is the acknowledgement.
    public var hoverLift: SpringCurve? {
        switch self {
        case let .morph(timing):
            return timing.hover
        case .crossFade:
            return nil
        }
    }
}

/// How much of the island's surroundings show through.
///
/// The island itself is always flat black — it is the camera housing grown
/// outward, and anything else would show a seam where it meets the housing —
/// so its text contrast never depends on the wallpaper. What this decides is
/// the decoration around it.
public enum BackgroundTreatment: Equatable, Sendable {
    /// A soft shadow lifts the island off whatever is behind it.
    case material
    /// No shadow or translucent falloff at all: the island's edge is exactly
    /// where its fill ends.
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
                : .morph(.standard),
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
