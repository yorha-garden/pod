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

    @Test("Appearing from hidden never animates the frame, whatever the motion setting",
          arguments: [AccessibilityPreferences.standard, AccessibilityPreferences(reduceMotion: true)])
    func appearingIsPlacedNotAnimated(preferences: AccessibilityPreferences) {
        let motion = IslandStyle.resolve(for: preferences).motion

        // There is no previous frame worth animating from: on the first
        // presentation it is wherever the panel was constructed.
        #expect(!motion.animatesFrameChange(panelWasOnScreen: false))
    }

    @Test("Between on-screen states the frame animates only when the morph is allowed")
    func onScreenChangesFollowReduceMotion() {
        let standard = IslandStyle.resolve(for: .standard).motion
        let reduced = IslandStyle.resolve(for: AccessibilityPreferences(reduceMotion: true)).motion

        #expect(standard.animatesFrameChange(panelWasOnScreen: true))
        #expect(!reduced.animatesFrameChange(panelWasOnScreen: true))
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
