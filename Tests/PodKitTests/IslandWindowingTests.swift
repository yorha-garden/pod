import Foundation
import Testing
@testable import PodKit

@Suite("Island windowing policy")
struct IslandWindowingTests {
    private let standard = IslandWindowing.standard

    @Test("A visible island, or a resting target, is on screen in the ordinary case")
    func ordinaryCase() {
        #expect(standard.panelsBelongOnScreen(state: .collapsed(.hover), hasRestingTarget: false, presence: .normal))
        #expect(standard.panelsBelongOnScreen(state: .hidden, hasRestingTarget: true, presence: .normal))
        #expect(!standard.panelsBelongOnScreen(state: .hidden, hasRestingTarget: false, presence: .normal))
    }

    @Test("The lock screen hides the island unless Pod opts in, with the private Space to reach it")
    func lockScreen() {
        let locked = SystemPresence(isScreenLocked: true)

        #expect(!standard.panelsBelongOnScreen(state: .expanded(.hover), hasRestingTarget: true, presence: locked))

        let optedIn = IslandWindowing(showsOnLockScreen: true)
        #expect(optedIn.panelsBelongOnScreen(state: .expanded(.hover), hasRestingTarget: true, presence: locked))

        let publicOnly = IslandWindowing(usesPrivateWindowServerAPI: false, showsOnLockScreen: true)
        #expect(!publicOnly.panelsBelongOnScreen(state: .expanded(.hover), hasRestingTarget: true, presence: locked))
    }

    @Test("The island never takes the keyboard on the lock screen")
    func noKeyFocusWhenLocked() {
        let optedIn = IslandWindowing(showsOnLockScreen: true)

        #expect(optedIn.allowsKeyFocus(presence: .normal))
        #expect(!optedIn.allowsKeyFocus(presence: SystemPresence(isScreenLocked: true)))
        #expect(!optedIn.allowsKeyFocus(presence: SystemPresence(isSessionActive: false)))
    }

    @Test("The island stays over full-screen apps unless asked to step aside")
    func fullScreen() {
        let fullScreen = SystemPresence(activeSpace: .fullScreen)

        #expect(standard.panelsBelongOnScreen(state: .collapsed(.hover), hasRestingTarget: true, presence: fullScreen))

        let stepsAside = IslandWindowing(hidesInFullScreen: true)
        #expect(!stepsAside.panelsBelongOnScreen(state: .collapsed(.hover), hasRestingTarget: true, presence: fullScreen))
        #expect(stepsAside.panelsBelongOnScreen(state: .collapsed(.hover), hasRestingTarget: true, presence: .normal))
    }

    @Test("Another user's session, or sleeping displays, take the island off screen")
    func sessionAndSleep() {
        #expect(!standard.panelsBelongOnScreen(
            state: .collapsed(.hover), hasRestingTarget: true, presence: SystemPresence(isSessionActive: false)
        ))
        #expect(!standard.panelsBelongOnScreen(
            state: .collapsed(.hover), hasRestingTarget: true, presence: SystemPresence(areScreensAsleep: true)
        ))
    }

    @Test("The window server's Space types map to desktop and full screen")
    func spaceKinds() {
        #expect(SpaceKind(windowServerType: 0) == .desktop)
        #expect(SpaceKind(windowServerType: 4) == .fullScreen)
        #expect(SpaceKind(windowServerType: 2) == .other(2))
    }

    @Test("Switches are read from defaults, and fall back when unset")
    func readsDefaults() throws {
        let suite = "dev.yorha.pod.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(IslandWindowing(defaults: defaults) == .standard)

        defaults.set(false, forKey: IslandWindowing.Key.usesPrivateWindowServerAPI)
        defaults.set(true, forKey: IslandWindowing.Key.showsOnLockScreen)
        defaults.set(true, forKey: IslandWindowing.Key.hidesInFullScreen)

        #expect(IslandWindowing(defaults: defaults) == IslandWindowing(
            usesPrivateWindowServerAPI: false,
            showsOnLockScreen: true,
            hidesInFullScreen: true
        ))
    }
}
