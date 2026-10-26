import Foundation

/// How long the island stays up before dismissing itself.
///
/// A fixed, short auto-dismiss is the most common accessibility defect in this
/// class of UI. Four seconds is ample if you glanced at it; it is nothing if a
/// screen reader is still reading the second line, or if reaching the trackpad
/// takes you a moment. So the timeout is derived rather than constant, and it
/// is never allowed to pull focus away from someone who is holding it.
public struct DismissPolicy: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case dismiss(after: TimeInterval)
        /// Stays until the user dismisses it — Escape, the hotkey, or a click.
        case stayUntilDismissed
    }

    /// What the user explicitly asked for, which outranks everything below.
    public enum UserPreference: Equatable, Sendable {
        case automatic
        case never
        case fixed(TimeInterval)
    }

    /// Timeout for a glance with no accessibility settings in play.
    public var base: TimeInterval
    /// Applied when the preferences imply assistive use.
    public var assistiveMultiplier: Double
    public var userPreference: UserPreference

    public init(
        base: TimeInterval = 4,
        assistiveMultiplier: Double = 3,
        userPreference: UserPreference = .automatic
    ) {
        self.base = base
        self.assistiveMultiplier = assistiveMultiplier
        self.userPreference = userPreference
    }

    public func outcome(
        reason: PresentationReason,
        hasKeyboardFocus: Bool,
        preferences: AccessibilityPreferences
    ) -> Outcome {
        switch userPreference {
        case .never:
            return .stayUntilDismissed
        case let .fixed(interval):
            // Still never yanked out from under a held focus.
            return hasKeyboardFocus ? .stayUntilDismissed : .dismiss(after: interval)
        case .automatic:
            break
        }

        // Dismissing a panel that holds the keyboard focus drops the user's
        // place in the focus order with no warning. Never do it on a timer.
        if hasKeyboardFocus {
            return .stayUntilDismissed
        }

        // They pressed the hotkey. Taking it away on a timer means racing a
        // user who deliberately asked for the thing.
        if reason == .keyboard {
            return .stayUntilDismissed
        }

        if preferences.impliesAssistiveUse {
            return .dismiss(after: base * assistiveMultiplier)
        }

        return .dismiss(after: base)
    }
}
