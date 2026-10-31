import Testing
@testable import PodKit

@MainActor
@Suite("Island controller")
struct IslandControllerTests {
    @Test("An incidental presentation dismisses itself")
    func incidentalPresentationExpires() async throws {
        let controller = IslandController(policy: DismissPolicy(base: 0.05), sink: RecordingSink())

        controller.present(.collapsed(.event(.mediaChanged)))
        #expect(controller.state.isVisible)

        try await Task.sleep(for: .milliseconds(250))

        #expect(controller.state == .hidden)
    }

    @Test("Keyboard focus cancels a dismiss already in flight")
    func focusCancelsPendingDismiss() async throws {
        let controller = IslandController(policy: DismissPolicy(base: 0.05), sink: RecordingSink())

        controller.present(.expanded(.event(.mediaChanged)))
        controller.setKeyboardFocus(true)

        try await Task.sleep(for: .milliseconds(250))

        #expect(controller.state.isVisible)
    }

    @Test("A keyboard summon is never taken away on a timer")
    func keyboardSummonPersists() async throws {
        let controller = IslandController(policy: DismissPolicy(base: 0.05), sink: RecordingSink())

        controller.present(.expanded(.keyboard))

        try await Task.sleep(for: .milliseconds(250))

        #expect(controller.state.isVisible)
    }

    @Test("Turning on a screen reader extends the timeout already running")
    func preferenceChangeExtendsTheTimeoutInFlight() async throws {
        let controller = IslandController(
            policy: DismissPolicy(base: 0.1, assistiveMultiplier: 6),
            sink: RecordingSink()
        )

        controller.present(.collapsed(.event(.mediaChanged)))
        controller.updatePreferences(AccessibilityPreferences(screenReaderActive: true))

        // Past the original 0.1s deadline, well inside the extended 0.6s one.
        try await Task.sleep(for: .milliseconds(300))

        #expect(controller.state.isVisible)
    }

    @Test("A repeated announcement is not spoken twice while the island stays up")
    func repeatedAnnouncementIsCoalesced() {
        let sink = RecordingSink()
        let controller = IslandController(
            policy: DismissPolicy(userPreference: .never),
            sink: sink
        )
        let announcement = Announcement("Now playing, Weight of the World")

        controller.present(.collapsed(.event(.mediaChanged)), announcing: announcement)
        controller.present(.expanded(.hover), announcing: announcement)

        #expect(sink.posted.count == 1)
    }

    @Test("Dismissing drops the keyboard focus flag")
    func dismissClearsFocus() {
        let controller = IslandController(sink: RecordingSink())

        controller.present(.expanded(.keyboard))
        controller.setKeyboardFocus(true)
        controller.dismiss()

        #expect(controller.state == .hidden)
        #expect(!controller.hasKeyboardFocus)
    }

    @Test("Style tracks the accessibility preferences")
    func styleTracksPreferences() {
        let controller = IslandController(sink: RecordingSink())
        #expect(controller.style.motion.allowsGeometryMorph)

        controller.updatePreferences(AccessibilityPreferences(reduceMotion: true))

        #expect(!controller.style.motion.allowsGeometryMorph)
    }
}
