import Testing
@testable import PodKit

@Suite("Island style resolution")
struct IslandStyleTests {
    @Test("Default preferences keep the morph and the material")
    func defaultPreferences() {
        let style = IslandStyle.resolve(for: .standard)

        #expect(style.motion.allowsGeometryMorph)
        #expect(style.background == .material)
        #expect(style.borderWidth == 0)
    }

    @Test("Reduce Motion replaces the morph with a fade in place")
    func reduceMotion() {
        let style = IslandStyle.resolve(for: AccessibilityPreferences(reduceMotion: true))

        #expect(!style.motion.allowsGeometryMorph)
        #expect(style.motion == .crossFade(duration: 0.12))
    }

    @Test("Reduce Transparency makes the surface opaque")
    func reduceTransparency() {
        let style = IslandStyle.resolve(for: AccessibilityPreferences(reduceTransparency: true))

        #expect(style.background == .opaque)
    }

    @Test("Increase Contrast adds a border and drops the blur")
    func increaseContrast() {
        let style = IslandStyle.resolve(for: AccessibilityPreferences(increaseContrast: true))

        // A blur hands the wallpaper control of the text's contrast, so
        // Increase Contrast has to imply an opaque fill, not just a border.
        #expect(style.background == .opaque)
        #expect(style.borderWidth == 2)
    }

    @Test("Opening springs out with a bounce, closing settles without one")
    func openingAndClosingSprings() {
        let motion = IslandStyle.resolve(for: .standard).motion

        let opening = motion.motion(for: IslandTransition(from: .collapsed(.hover), to: .expanded(.hover)))
        let closing = motion.motion(for: IslandTransition(from: .expanded(.hover), to: .hidden))

        #expect(opening == .spring(.bounce(duration: 0.44, bounce: 0.375)))
        #expect(closing == .spring(.response(0.4, dampingFraction: 1)))
        guard case let .spring(open) = opening, case let .spring(close) = closing else {
            Issue.record("expected springs")
            return
        }
        #expect(open.overshoots)
        // The island must never bounce past the housing it returns into.
        #expect(!close.overshoots)
    }

    @Test("Growing out of the housing uses the opening spring")
    func appearingGrowsOutOfTheHousing() {
        let motion = IslandStyle.resolve(for: .standard).motion

        #expect(motion.motion(for: IslandTransition(from: .hidden, to: .collapsed(.event(.mediaChanged))))
            == .spring(MorphTiming.standard.open))
    }

    @Test("Changing content without changing size settles without overshoot")
    func holdingStepsSettle() {
        let motion = IslandStyle.resolve(for: .standard).motion
        let step = IslandTransition(from: .collapsed(.event(.mediaChanged)), to: .collapsed(.event(.batteryLow)))

        #expect(step.direction == .holding)
        #expect(motion.motion(for: step) == .spring(MorphTiming.standard.settle))
        #expect(!MorphTiming.standard.settle.overshoots)
    }

    @Test("Reduce Motion fades every transition in place and drops the hover lift",
          arguments: [
              IslandTransition(from: .hidden, to: .collapsed(.hover)),
              IslandTransition(from: .collapsed(.hover), to: .expanded(.hover)),
              IslandTransition(from: .expanded(.keyboard), to: .hidden),
              IslandTransition(from: .collapsed(.hover), to: .collapsed(.keyboard)),
          ])
    func reduceMotionFadesEverything(transition: IslandTransition) {
        let motion = IslandStyle.resolve(for: AccessibilityPreferences(reduceMotion: true)).motion

        #expect(motion.motion(for: transition) == .fade(duration: 0.12))
        #expect(motion.hoverLift == nil)
    }

    @Test("A held click dips the lifted island 8 by 5 points, on a spring that does not bounce")
    func pressDip() {
        let motion = IslandStyle.resolve(for: .standard).motion

        #expect(HoverLift.outset(lifted: true, pressed: false) == .standard)
        #expect(HoverLift.outset(lifted: true, pressed: true) == HoverLift(width: 6, height: 1))
        #expect(HoverLift.standard.width - HoverLift.pressed.width == 8)
        #expect(HoverLift.standard.height - HoverLift.pressed.height == 5)
        #expect(HoverLift.outset(lifted: false, pressed: true) == .none)

        #expect(motion.pressDip?.overshoots == false)
    }

    @Test("Reduce Motion drops the dip as well as the lift")
    func reduceMotionDropsTheDip() {
        let motion = IslandStyle.resolve(for: AccessibilityPreferences(reduceMotion: true)).motion

        #expect(motion.pressDip == nil)
    }

    @Test("Content grows into focus from the island's centre, and under Reduce Motion only fades")
    func contentEntrance() {
        let standard = IslandStyle.resolve(for: .standard).motion
        let reduced = IslandStyle.resolve(for: AccessibilityPreferences(reduceMotion: true)).motion
        let opening = IslandTransition(from: .hidden, to: .expanded(.hover))

        #expect(standard.motion(for: opening).contentEntrance == ContentEntrance(scale: 0.5, blur: 4))
        #expect(reduced.motion(for: opening).contentEntrance == ContentEntrance(scale: 1, blur: 0))
    }

    @Test("Without Reduce Motion the pointer gets a short springy lift")
    func hoverLiftWithoutReduceMotion() {
        let motion = IslandStyle.resolve(for: .standard).motion

        #expect(motion.hoverLift == .bounce(duration: 0.35, bounce: 0.3))
        #expect(HoverLift.standard.width > 0 && HoverLift.standard.height > 0)
    }

    @Test("Colour is never the only state cue, and the hit floor always holds",
          arguments: 0..<16)
    func invariantsHoldForEveryCombination(mask: Int) {
        let preferences = AccessibilityPreferences(
            reduceMotion: mask & 1 != 0,
            reduceTransparency: mask & 2 != 0,
            increaseContrast: mask & 4 != 0,
            differentiateWithoutColor: mask & 8 != 0
        )

        let style = IslandStyle.resolve(for: preferences)

        #expect(style.requiresNonColorStateCue)
        #expect(style.minimumHitTarget == IslandStyle.hitTargetFloor)
    }
}
