import Testing
@testable import PodKit

@Suite("Dismiss timing")
struct DismissPolicyTests {
    @Test("An incidental event dismisses on the base timeout")
    func incidentalEvent() {
        let policy = DismissPolicy(base: 4)

        let outcome = policy.outcome(
            reason: .event(.mediaChanged),
            hasKeyboardFocus: false,
            preferences: .standard
        )

        #expect(outcome == .dismiss(after: 4))
    }

    @Test("A screen reader gets the extended timeout")
    func screenReaderGetsLonger() {
        let policy = DismissPolicy(base: 4, assistiveMultiplier: 3)

        let outcome = policy.outcome(
            reason: .event(.mediaChanged),
            hasKeyboardFocus: false,
            preferences: AccessibilityPreferences(screenReaderActive: true)
        )

        #expect(outcome == .dismiss(after: 12))
    }

    @Test("Full Keyboard Access gets the extended timeout too")
    func keyboardAccessGetsLonger() {
        let policy = DismissPolicy(base: 4, assistiveMultiplier: 3)

        let outcome = policy.outcome(
            reason: .event(.batteryLow),
            hasKeyboardFocus: false,
            preferences: AccessibilityPreferences(fullKeyboardAccess: true)
        )

        #expect(outcome == .dismiss(after: 12))
    }

    @Test("Held keyboard focus is never dismissed on a timer")
    func heldFocusIsNeverTimedOut() {
        let policy = DismissPolicy()

        let outcome = policy.outcome(
            reason: .event(.volumeChanged),
            hasKeyboardFocus: true,
            preferences: .standard
        )

        #expect(outcome == .stayUntilDismissed)
    }

    @Test("A keyboard summon stays until the user dismisses it")
    func keyboardSummonStays() {
        let policy = DismissPolicy()

        let outcome = policy.outcome(
            reason: .keyboard,
            hasKeyboardFocus: false,
            preferences: .standard
        )

        #expect(outcome == .stayUntilDismissed)
    }

    @Test("The never preference outranks an incidental event")
    func neverPreferenceWins() {
        let policy = DismissPolicy(userPreference: .never)

        let outcome = policy.outcome(
            reason: .event(.mediaChanged),
            hasKeyboardFocus: false,
            preferences: .standard
        )

        #expect(outcome == .stayUntilDismissed)
    }

    @Test("A fixed preference is honoured but still yields to held focus")
    func fixedPreferenceYieldsToFocus() {
        let policy = DismissPolicy(userPreference: .fixed(10))

        #expect(
            policy.outcome(reason: .hover, hasKeyboardFocus: false, preferences: .standard)
                == .dismiss(after: 10)
        )
        #expect(
            policy.outcome(reason: .hover, hasKeyboardFocus: true, preferences: .standard)
                == .stayUntilDismissed
        )
    }
}
